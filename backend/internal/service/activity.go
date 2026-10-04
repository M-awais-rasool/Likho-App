package service

import (
	"context"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"sync"
	"time"

	"likho/backend/internal/cache"
	"likho/backend/internal/geo"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ActivityService records what families do, for the admin panel: when and
// where they use the app (last seen, active days, country, device), an
// event per action, and alerts for the team (e.g. a child reached the last
// level). Recording never fails a request: problems are only logged.
type ActivityService struct {
	repo     *repository.ActivityRepository
	admin    *repository.AdminRepository
	cache    *cache.Cache
	geo      *geo.Resolver
	seenTTL  time.Duration
	rulesTTL time.Duration

	mu      sync.Mutex
	rules   AlertRules
	rulesAt time.Time
}

func NewActivityService(repo *repository.ActivityRepository, admin *repository.AdminRepository, c *cache.Cache, g *geo.Resolver) *ActivityService {
	if g == nil {
		g = &geo.Resolver{}
	}
	return &ActivityService{repo: repo, admin: admin, cache: c, geo: g, seenTTL: 5 * time.Minute, rulesTTL: 30 * time.Second}
}

// AlertRules says which alerts the team gets (admin panel settings).
type AlertRules struct {
	ReachedEnd      bool `json:"reachedEnd"`      // a child is on the last level(s): add more
	LevelsBeforeEnd int  `json:"levelsBeforeEnd"` // 1 = on the last level, 3 = three levels left
	CourseCompleted bool `json:"courseCompleted"`
	NewSignup       bool `json:"newSignup"`
	TrialStarted    bool `json:"trialStarted"`
}

var DefaultAlertRules = AlertRules{ReachedEnd: true, LevelsBeforeEnd: 1, CourseCompleted: true}

const alertRulesKey = "alerts"

// Rules returns the alert rules (read at most every 30 s).
func (s *ActivityService) Rules(ctx context.Context) AlertRules {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.rulesAt.IsZero() && time.Since(s.rulesAt) < s.rulesTTL {
		return s.rules
	}
	r := DefaultAlertRules
	if _, err := s.admin.Setting(ctx, alertRulesKey, &r); err != nil {
		slog.Warn("alert rules", "err", err)
	}
	s.rules, s.rulesAt = r, time.Now()
	return r
}

// SetRules saves new alert rules.
func (s *ActivityService) SetRules(ctx context.Context, r AlertRules) (AlertRules, error) {
	r.LevelsBeforeEnd = min(max(r.LevelsBeforeEnd, 1), 10)
	if err := s.admin.SetSetting(ctx, alertRulesKey, r); err != nil {
		return r, err
	}
	s.mu.Lock()
	s.rules, s.rulesAt = r, time.Now()
	s.mu.Unlock()
	return r, nil
}

var (
	versionRe = regexp.MustCompile(`^[0-9A-Za-z.+\-]{1,32}$`)
	platforms = map[string]bool{"ios": true, "android": true, "web": true, "macos": true, "windows": true, "linux": true}
)

// Seen records that the parent is using the app now. Most requests only
// check Redis: the database is written at most every 5 minutes per parent
// (or at once when [force], e.g. at sign-in).
func (s *ActivityService) Seen(ctx context.Context, parentID string, info model.ClientInfo, force bool) {
	if !force && !s.cache.FirstIn(ctx, "seen:"+parentID, s.seenTTL) {
		return
	}
	seen := repository.Seen{}
	seen.Country, seen.CountrySource = s.geo.Country(info.CountryHeader, info.IP, info.Region)
	if p := strings.ToLower(strings.TrimSpace(info.Platform)); platforms[p] {
		seen.Platform = p
	}
	if v := strings.TrimSpace(info.AppVersion); versionRe.MatchString(v) {
		seen.AppVersion = v
	}
	if err := s.repo.Touch(ctx, parentID, seen); err != nil {
		slog.Warn("activity: seen", "parent", parentID, "err", err)
	}
}

// Event records something a family did.
func (s *ActivityService) Event(ctx context.Context, ev model.ActivityEvent) {
	if err := s.repo.Add(ctx, &ev); err != nil {
		slog.Warn("activity: event", "type", ev.Type, "err", err)
	}
}

func ptr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// SignedIn records a sign-in (or the sign-up of a new account).
func (s *ActivityService) SignedIn(ctx context.Context, p model.Parent, created bool, info model.ClientInfo) {
	s.Seen(ctx, p.ID, info, true)
	typ := model.EventSignedIn
	if created {
		typ = model.EventSignedUp
	}
	s.Event(ctx, model.ActivityEvent{Type: typ, ParentID: &p.ID})
	if created && s.Rules(ctx).NewSignup {
		s.alert(ctx, &model.AdminAlert{
			Kind: model.AlertNewSignup, Key: "signup:" + p.ID, ParentID: &p.ID,
			Title: "New family signed up", Body: strings.TrimSpace(p.Name + " " + p.Email),
		})
	}
}

// TrialStarted records a Likho Plus trial.
func (s *ActivityService) TrialStarted(ctx context.Context, parentID string) {
	s.Event(ctx, model.ActivityEvent{Type: model.EventTrialStarted, ParentID: &parentID})
	if s.Rules(ctx).TrialStarted {
		s.alert(ctx, &model.AdminAlert{
			Kind: model.AlertTrialStarted, Key: "trial:" + parentID, ParentID: &parentID,
			Title: "A family started the Likho Plus trial",
		})
	}
}

// LevelCompleted records a finished level and raises the end-of-course
// alerts: when a child (finishing a level for the first time) is now
// [LevelsBeforeEnd] levels from the end, and when they finish the last one.
func (s *ActivityService) LevelCompleted(ctx context.Context, parentID, childID, courseID string, out model.Outcome, seconds, lastLevel int) {
	s.Event(ctx, model.ActivityEvent{
		Type: model.EventLevelCompleted, ParentID: &parentID, ChildID: &childID, CourseID: courseID,
		Level: out.Level, Stars: out.Stars, Seconds: seconds,
		Detail: model.JSONOf(map[string]any{"firstTime": out.FirstTime, "gain": out.Gain, "bestStars": out.BestStars}),
	})
	if !out.FirstTime {
		return
	}
	rules := s.Rules(ctx)
	reachedEnd := rules.ReachedEnd && out.Level == lastLevel-rules.LevelsBeforeEnd
	completed := out.Level == lastLevel
	if completed {
		s.Event(ctx, model.ActivityEvent{Type: model.EventCourseCompleted, ParentID: &parentID, ChildID: &childID, CourseID: courseID, Level: out.Level})
	}
	if !reachedEnd && !(completed && rules.CourseCompleted) {
		return
	}
	who, err := s.repo.Learner(ctx, childID)
	if err != nil {
		slog.Warn("activity: learner", "err", err)
	}
	family := strings.TrimSpace(fmt.Sprintf("%s · %s", who.ParentEmail, who.Country))
	if reachedEnd {
		left := lastLevel - out.Level
		title := fmt.Sprintf("%s reached the last level (%d)", who.ChildName, lastLevel)
		if left > 1 {
			title = fmt.Sprintf("%s has %d levels left (finished %d of %d)", who.ChildName, left, out.Level, lastLevel)
		}
		s.alert(ctx, &model.AdminAlert{
			Kind: model.AlertReachedEnd, Key: fmt.Sprintf("end:%s:%s:%d", childID, courseID, out.Level),
			ParentID: &parentID, ChildID: ptr(childID), CourseID: courseID, Level: out.Level,
			Title: title, Body: "Add new levels so they can keep learning. " + family,
		})
	}
	if completed && rules.CourseCompleted {
		s.alert(ctx, &model.AdminAlert{
			Kind: model.AlertCourseCompleted, Key: fmt.Sprintf("done:%s:%s:%d", childID, courseID, out.Level),
			ParentID: &parentID, ChildID: ptr(childID), CourseID: courseID, Level: out.Level,
			Title: fmt.Sprintf("%s finished all %d levels!", who.ChildName, lastLevel),
			Body:  "They have nothing new to play until new levels are published. " + family,
		})
	}
}

func (s *ActivityService) alert(ctx context.Context, a *model.AdminAlert) {
	a.At = time.Now()
	if _, err := s.repo.AddAlert(ctx, a); err != nil {
		slog.Warn("activity: alert", "kind", a.Kind, "err", err)
	}
}
