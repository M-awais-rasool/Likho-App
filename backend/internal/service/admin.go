package service

import (
	"context"
	"time"

	"likho/backend/internal/cache"
	"likho/backend/internal/catalog"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// AdminService: what the admin panel reads (dashboard, families, learners,
// levels, activity, alerts) and the support actions it can take on an
// account. Every change is written to the audit log.
type AdminService struct {
	insights *repository.InsightsRepository
	admin    *repository.AdminRepository
	accounts *repository.AccountRepository
	children *repository.ChildRepository
	sessions *repository.SessionRepository
	play     *repository.PlayRepository
	catalog  *catalog.Store
	cache    *cache.Cache
	activity *ActivityService
	account  *AccountService
}

func NewAdminService(r repository.Repositories, cat *catalog.Store, c *cache.Cache, activity *ActivityService, account *AccountService) *AdminService {
	return &AdminService{
		insights: r.Insights, admin: r.Admin, accounts: r.Accounts, children: r.Children, sessions: r.Sessions, play: r.Play,
		catalog: cat, cache: c, activity: activity, account: account,
	}
}

// Actor is the admin making a change (for the audit log).
type Actor struct {
	ID, Email string
}

// Audit records a change made in the panel.
func (s *AdminService) Audit(ctx context.Context, by Actor, action, target string, detail any) {
	_ = s.admin.Audit(ctx, auditEntry(by, action, target, detail))
}

// auditEntry is one line of the audit log; a zero [by] is nobody signed in
// (a failed sign-in).
func auditEntry(by Actor, action, target string, detail any) *model.AuditEntry {
	e := &model.AuditEntry{AdminEmail: by.Email, Action: action, Target: target, Detail: model.JSONOf(detail)}
	if by.ID != "" {
		e.AdminID = &by.ID
	}
	return e
}

func (s *AdminService) AuditLog(ctx context.Context, before int64, limit int) ([]model.AuditEntry, error) {
	out, err := s.admin.AuditLog(ctx, before, limit)
	if out == nil {
		out = []model.AuditEntry{}
	}
	return out, err
}

// CourseOf returns the served course (and its last level).
func (s *AdminService) CourseOf(id string) (*catalog.Course, error) {
	c, ok := s.catalog.Get().Course(id)
	if !ok {
		return nil, domain.ErrCourseNotFound
	}
	return c, nil
}

// ------------------------------------------------------------- dashboard

type OverviewOut struct {
	repository.Overview
	Course       model.CourseSummary    `json:"course"`
	LastLevel    int                    `json:"lastLevel"`
	Funnel       []repository.LevelStat `json:"funnel"`
	NotStarted   int64                  `json:"notStarted"`
	Unread       int64                  `json:"unreadAlerts"`
	RecentAlerts []repository.AlertView `json:"recentAlerts"`
	Recent       []repository.EventRow  `json:"recentActivity"`
	Courses      []model.CourseSummary  `json:"courses"`
}

func (s *AdminService) Overview(ctx context.Context, courseID string, days int) (OverviewOut, error) {
	c, err := s.CourseOf(courseID)
	if err != nil {
		return OverviewOut{}, err
	}
	days = min(max(days, 7), 365)
	o, err := s.insights.Overview(ctx, courseID, c.LastLevel(), days)
	if err != nil {
		return OverviewOut{}, err
	}
	stats, err := s.insights.LevelStats(ctx, courseID, c.LastLevel())
	if err != nil {
		return OverviewOut{}, err
	}
	unread, _, err := s.admin.UnreadAlerts(ctx)
	if err != nil {
		return OverviewOut{}, err
	}
	alerts, err := s.admin.Alerts(ctx, false, 0, 5)
	if err != nil {
		return OverviewOut{}, err
	}
	recent, err := s.insights.Events(ctx, repository.EventQuery{Limit: 8})
	if err != nil {
		return OverviewOut{}, err
	}
	out := OverviewOut{
		Overview: o, Course: c.Summary, LastLevel: c.LastLevel(), Funnel: stats.Levels, NotStarted: stats.NotStart,
		Unread: unread, RecentAlerts: nonNil(alerts), Recent: nonNil(recent),
	}
	for _, sc := range s.catalog.Get().Courses() {
		out.Courses = append(out.Courses, sc.Summary)
	}
	out.Series, out.Countries, out.Platforms, out.Versions, out.Ages = nonNil(o.Series), nonNil(o.Countries), nonNil(o.Platforms), nonNil(o.Versions), nonNil(o.Ages)
	return out, nil
}

func nonNil[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}

// ---------------------------------------------------------------- lists

type Page[T any] struct {
	Items    []T   `json:"items"`
	Total    int64 `json:"total"`
	Page     int   `json:"page"`
	PageSize int   `json:"pageSize"`
}

func (s *AdminService) Families(ctx context.Context, courseID string, q repository.ListQuery) (Page[repository.FamilyRow], error) {
	rows, total, err := s.insights.Families(ctx, courseID, q)
	return Page[repository.FamilyRow]{Items: nonNil(rows), Total: total, Page: q.Page, PageSize: q.PageSize}, err
}

func (s *AdminService) Learners(ctx context.Context, courseID string, q repository.ListQuery) (Page[repository.LearnerRow], error) {
	c, err := s.CourseOf(courseID)
	if err != nil {
		return Page[repository.LearnerRow]{}, err
	}
	rows, total, err := s.insights.Learners(ctx, courseID, c.LastLevel(), q)
	return Page[repository.LearnerRow]{Items: nonNil(rows), Total: total, Page: q.Page, PageSize: q.PageSize}, err
}

// FamilyDetail is everything about one account.
type FamilyDetail struct {
	Family       repository.FamilyRow       `json:"family"`
	Subscription model.Subscription         `json:"subscription"`
	Settings     model.Settings             `json:"settings"`
	Children     []model.ChildView          `json:"children"`
	Devices      []repository.DeviceSession `json:"devices"`
	Activity     []repository.EventRow      `json:"activity"`
	LastLevel    int                        `json:"lastLevel"`
	Purchases    []PurchaseView             `json:"purchases"`
}

// PurchaseView is a Google Play purchase of Likho Plus in the panel.
type PurchaseView struct {
	Token        string    `json:"token"` // the end of the purchase token, to tell them apart
	Plan         string    `json:"plan"`
	Offer        string    `json:"offer"`
	State        string    `json:"state"`
	ExpiresAt    time.Time `json:"expiresAt"`
	AutoRenewing bool      `json:"autoRenewing"`
	OrderID      string    `json:"orderId"`
	Test         bool      `json:"test"`
	CreatedAt    time.Time `json:"createdAt"`
}

func (s *AdminService) Family(ctx context.Context, courseID, parentID string) (FamilyDetail, error) {
	c, err := s.CourseOf(courseID)
	if err != nil {
		return FamilyDetail{}, err
	}
	f, err := s.insights.Family(ctx, courseID, parentID)
	if err != nil {
		return FamilyDetail{}, err
	}
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return FamilyDetail{}, err
	}
	kids, err := s.children.Views(ctx, parentID)
	if err != nil {
		return FamilyDetail{}, err
	}
	devices, err := s.insights.Devices(ctx, parentID)
	if err != nil {
		return FamilyDetail{}, err
	}
	events, err := s.insights.Events(ctx, repository.EventQuery{ParentID: parentID, Limit: 60})
	if err != nil {
		return FamilyDetail{}, err
	}
	sub, err := subscriptionOf(ctx, s.play, p, time.Now())
	if err != nil {
		return FamilyDetail{}, err
	}
	rows, err := s.play.ForParent(ctx, parentID)
	if err != nil {
		return FamilyDetail{}, err
	}
	purchases := make([]PurchaseView, 0, len(rows))
	for _, r := range rows {
		tok := r.PurchaseToken
		if len(tok) > 10 {
			tok = "…" + tok[len(tok)-10:]
		}
		purchases = append(purchases, PurchaseView{Token: tok, Plan: r.BasePlanID, Offer: r.OfferID, State: r.State, ExpiresAt: r.ExpiresAt,
			AutoRenewing: r.AutoRenewing, OrderID: r.OrderID, Test: r.Test, CreatedAt: r.CreatedAt})
	}
	return FamilyDetail{
		Family: f, Subscription: sub, Settings: p.Settings(), Children: nonNil(kids),
		Devices: nonNil(devices), Activity: nonNil(events), LastLevel: c.LastLevel(), Purchases: purchases,
	}, nil
}

// -------------------------------------------------------------- actions

// GrantPlus gives Likho Plus for [days] more days (from today, or from the
// end of the current Plus).
func (s *AdminService) GrantPlus(ctx context.Context, by Actor, parentID string, days int) (model.Subscription, error) {
	if days < 1 || days > 3650 {
		return model.Subscription{}, domain.Invalid("days must be 1 to 3650")
	}
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return model.Subscription{}, err
	}
	from := time.Now()
	if p.PlusUntil != nil && p.PlusUntil.After(from) {
		from = *p.PlusUntil
	}
	until := from.Add(time.Duration(days) * 24 * time.Hour)
	if err := s.accounts.SetPlusUntil(ctx, parentID, &until); err != nil {
		return model.Subscription{}, err
	}
	s.cache.ForgetMe(ctx, parentID)
	s.Audit(ctx, by, "family.plus_granted", parentID, map[string]any{"days": days, "until": until, "email": p.Email})
	p.PlusUntil = &until
	return p.Subscription(time.Now()), nil
}

// RevokePlus ends Likho Plus now.
func (s *AdminService) RevokePlus(ctx context.Context, by Actor, parentID string) (model.Subscription, error) {
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return model.Subscription{}, err
	}
	now := time.Now()
	if err := s.accounts.SetPlusUntil(ctx, parentID, &now); err != nil {
		return model.Subscription{}, err
	}
	s.cache.ForgetMe(ctx, parentID)
	s.Audit(ctx, by, "family.plus_revoked", parentID, map[string]any{"email": p.Email})
	p.PlusUntil = &now
	return p.Subscription(now), nil
}

// SignOutEverywhere ends every session of the account (phones must sign in
// again).
func (s *AdminService) SignOutEverywhere(ctx context.Context, by Actor, parentID string) error {
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return err
	}
	if err := s.sessions.RevokeAll(ctx, parentID); err != nil {
		return err
	}
	s.Audit(ctx, by, "family.signed_out", parentID, map[string]any{"email": p.Email})
	return nil
}

// DeleteFamily deletes the account and everything in it (as the parent
// can in the app).
func (s *AdminService) DeleteFamily(ctx context.Context, by Actor, parentID string) error {
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return err
	}
	if err := s.account.Delete(ctx, parentID); err != nil {
		return err
	}
	s.Audit(ctx, by, "family.deleted", parentID, map[string]any{"email": p.Email, "country": p.Country})
	return nil
}

// AdjustStars adds (or with a negative [delta] removes) stars of a child,
// e.g. to make up for a problem. The balance never goes below 0.
func (s *AdminService) AdjustStars(ctx context.Context, by Actor, childID string, delta int, reason string) (int, error) {
	if delta == 0 || delta < -10000 || delta > 10000 {
		return 0, domain.Invalid("delta must be between -10000 and 10000 and not 0")
	}
	parentID, stars, err := s.children.AdjustStars(ctx, childID, delta)
	if err != nil {
		return 0, err
	}
	s.cache.ForgetMe(ctx, parentID)
	s.Audit(ctx, by, "child.stars_adjusted", childID, map[string]any{"delta": delta, "stars": stars, "reason": reason, "parentId": parentID})
	return stars, nil
}

// ------------------------------------------------------------ analytics

func (s *AdminService) LevelStats(ctx context.Context, courseID string) (repository.LevelStats, error) {
	c, err := s.CourseOf(courseID)
	if err != nil {
		return repository.LevelStats{}, err
	}
	out, err := s.insights.LevelStats(ctx, courseID, c.LastLevel())
	out.Levels = nonNil(out.Levels)
	return out, err
}

func (s *AdminService) Events(ctx context.Context, q repository.EventQuery) ([]repository.EventRow, error) {
	q.Limit = min(max(q.Limit, 1), 200)
	out, err := s.insights.Events(ctx, q)
	return nonNil(out), err
}

// --------------------------------------------------------------- alerts

func (s *AdminService) Alerts(ctx context.Context, unread bool, before int64, limit int) ([]repository.AlertView, error) {
	out, err := s.admin.Alerts(ctx, unread, before, min(max(limit, 1), 200))
	return nonNil(out), err
}

func (s *AdminService) UnreadAlerts(ctx context.Context) (int64, int64, error) {
	return s.admin.UnreadAlerts(ctx)
}

func (s *AdminService) MarkAlertsRead(ctx context.Context, by Actor, ids []int64) error {
	return s.admin.MarkAlertsRead(ctx, ids, by.Email)
}

func (s *AdminService) AlertRules(ctx context.Context) AlertRules { return s.activity.Rules(ctx) }

func (s *AdminService) SetAlertRules(ctx context.Context, by Actor, r AlertRules) (AlertRules, error) {
	out, err := s.activity.SetRules(ctx, r)
	if err == nil {
		s.Audit(ctx, by, "settings.alerts", "alerts", out)
	}
	return out, err
}

// ---------------------------------------------------------------- system

func (s *AdminService) TableSizes(ctx context.Context) (map[string]int64, error) {
	return s.insights.TableSizes(ctx)
}
