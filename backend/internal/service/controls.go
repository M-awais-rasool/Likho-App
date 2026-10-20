package service

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"likho/backend/internal/catalog"
	"likho/backend/internal/domain"
	"likho/backend/internal/repository"
)

// ControlsService keeps the App controls (admin panel) and tells each app
// what is on for it (GET /v1/config). The saved controls are read at most
// every 15 s; a save shows at once on this server.
type ControlsService struct {
	admin    *repository.AdminRepository
	accounts *repository.AccountRepository
	catalog  *catalog.Store
	ttl      time.Duration
	now      func() time.Time

	mu    sync.Mutex
	saved SavedControls
	at    time.Time
}

func NewControlsService(admin *repository.AdminRepository, accounts *repository.AccountRepository, cat *catalog.Store) *ControlsService {
	return &ControlsService{admin: admin, accounts: accounts, catalog: cat, ttl: 15 * time.Second, now: time.Now}
}

const controlsKey = "app_controls"

// SavedControls are the controls with who saved them last. Revision goes
// up with every save (a save from an older revision is refused, so two
// admins never undo each other's changes unseen).
type SavedControls struct {
	Controls  domain.Controls `json:"controls"`
	Revision  int             `json:"revision"`
	UpdatedAt *time.Time      `json:"updatedAt"`
	UpdatedBy string          `json:"updatedBy"`
}

// ErrControlsChanged: another admin saved in the meantime.
var ErrControlsChanged = &domain.Error{Kind: domain.KindConflict, Code: "controls_changed", Message: "Someone saved the controls in the meantime; reload to see their changes"}

// Defaults are the controls before any save: free levels as the content
// says (the levels from 1 that need no Plus).
func (s *ControlsService) Defaults() domain.Controls {
	free := -1
	for _, c := range s.catalog.Get().Courses() {
		n := 0
		for i := 1; i <= c.Stats.Levels; i++ {
			l, ok := c.Level(i)
			if !ok || l.RequiresSubscription {
				break
			}
			n = i
		}
		if free < 0 || n < free {
			free = n
		}
	}
	return domain.DefaultControls(max(free, 0))
}

// LastLevel is the highest level number of any course (the limit for
// level counts).
func (s *ControlsService) LastLevel() int {
	last := 0
	for _, c := range s.catalog.Get().Courses() {
		last = max(last, c.LastLevel())
	}
	return last
}

// Saved returns the controls (defaults filled in).
func (s *ControlsService) Saved(ctx context.Context) SavedControls {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.at.IsZero() && s.now().Sub(s.at) < s.ttl {
		return s.saved
	}
	def := s.Defaults()
	var out SavedControls
	found, err := s.admin.Setting(ctx, controlsKey, &out)
	if err != nil {
		slog.Warn("app controls", "err", err)
		if !s.at.IsZero() {
			return s.saved // keep the last good ones
		}
	}
	if !found || err != nil {
		out = SavedControls{Controls: def}
	}
	out.Controls = out.Controls.Fill(def)
	s.saved, s.at = out, s.now()
	return out
}

// FamilyCounts counts the families' own switches.
func (s *ControlsService) FamilyCounts(ctx context.Context) ([]repository.FeatureCount, error) {
	out, err := s.accounts.FeatureCounts(ctx)
	if out == nil {
		out = []repository.FeatureCount{}
	}
	return out, err
}

// Controls is Saved without who saved them.
func (s *ControlsService) Controls(ctx context.Context) domain.Controls { return s.Saved(ctx).Controls }

// Save checks and saves the controls; [revision] is the one the admin
// started from.
func (s *ControlsService) Save(ctx context.Context, by Actor, in domain.Controls, revision int) (SavedControls, error) {
	in = in.Fill(s.Defaults())
	if err := in.Validate(s.LastLevel()); err != nil {
		return SavedControls{}, err
	}
	s.mu.Lock()
	s.at = time.Time{} // read the latest from the database
	s.mu.Unlock()
	old := s.Saved(ctx)
	if revision != old.Revision {
		return SavedControls{}, ErrControlsChanged
	}
	now := s.now()
	out := SavedControls{Controls: in, Revision: old.Revision + 1, UpdatedAt: &now, UpdatedBy: by.Email}
	if err := s.admin.SetSetting(ctx, controlsKey, out); err != nil {
		return SavedControls{}, err
	}
	s.mu.Lock()
	s.saved, s.at = out, now
	s.mu.Unlock()
	_ = s.admin.Audit(ctx, auditEntry(by, "settings.app_controls", "app", map[string]any{"revision": out.Revision, "changed": changedSections(old.Controls, in)}))
	return out, nil
}

// changedSections names the parts of the controls that differ.
func changedSections(a, b domain.Controls) []string {
	same := func(x, y any) bool {
		bx, _ := json.Marshal(x)
		by, _ := json.Marshal(y)
		return string(bx) == string(by)
	}
	out := []string{}
	for _, p := range []struct {
		name string
		x, y any
	}{
		{"features", a.Features, b.Features}, {"stories", a.Stories, b.Stories}, {"room", a.Room, b.Room},
		{"games", a.Games, b.Games}, {"pencilColors", a.PencilColors, b.PencilColors},
		{"billing", a.Billing, b.Billing}, {"app", a.App, b.App},
	} {
		if !same(p.x, p.y) {
			out = append(out, p.name)
		}
	}
	return out
}

// ------------------------------------------------------------ the app

// AppConfig is what the app follows (GET /v1/config), for one family (or
// a guest). Switches are off, on, or plus (on while the family has Plus).
type AppConfig struct {
	Revision     int                 `json:"revision"`
	Features     map[string]string   `json:"features"`
	Stories      AppStories          `json:"stories"`
	Room         domain.RoomControls `json:"room"`
	Games        map[string]bool     `json:"games"`
	PencilColors []string            `json:"pencilColors"`
	Billing      AppBilling          `json:"billing"`
	App          AppState            `json:"app"`
}

type AppStories struct {
	ComingSoon bool              `json:"comingSoon"`
	Episodes   map[string]string `json:"episodes"`
}

type AppBilling struct {
	domain.BillingControls
	// PlusFree: nobody needs Plus right now; FreeForAll: because of the
	// promotion (FreeForAllUntil).
	PlusFree   bool `json:"plusFree"`
	FreeForAll bool `json:"freeForAll"`
}

type AppState struct {
	MinVersion    string    `json:"minVersion"`
	Maintenance   AppNotice `json:"maintenance"`
	ParentMessage AppNotice `json:"parentMessage"`
}

type AppNotice struct {
	domain.Notice
	ID string `json:"id"`
}

// ForApp resolves the controls for [parentID] ("" = a guest).
func (s *ControlsService) ForApp(ctx context.Context, parentID string) (AppConfig, error) {
	saved := s.Saved(ctx)
	own := map[string]bool{}
	if parentID != "" {
		var err error
		if own, err = s.accounts.Features(ctx, parentID); err != nil {
			return AppConfig{}, err
		}
	}
	return resolveControls(saved, own, s.now()), nil
}

func resolveControls(saved SavedControls, own map[string]bool, now time.Time) AppConfig {
	c := saved.Controls
	plusFree := c.Billing.PlusFree(now)
	override := func(key string) *bool {
		if v, ok := own[key]; ok {
			return &v
		}
		return nil
	}
	out := AppConfig{
		Revision:     saved.Revision,
		Features:     map[string]string{},
		Stories:      AppStories{ComingSoon: c.Stories.ComingSoon, Episodes: map[string]string{}},
		Room:         c.Room,
		Games:        c.Games,
		PencilColors: c.PencilColors,
		Billing:      AppBilling{BillingControls: c.Billing, PlusFree: plusFree, FreeForAll: c.Billing.FreeForAll(now)},
		App: AppState{
			MinVersion:    c.App.MinVersion,
			Maintenance:   AppNotice{Notice: c.App.Maintenance, ID: c.App.Maintenance.ID()},
			ParentMessage: AppNotice{Notice: c.App.ParentMessage, ID: c.App.ParentMessage.ID()},
		},
	}
	for id, m := range c.Features {
		out.Features[id] = domain.Resolve(m, override(id), plusFree)
	}
	for id, m := range c.Stories.Episodes {
		out.Stories.Episodes[id] = domain.Resolve(m, override("story."+id), plusFree)
	}
	return out
}

// ------------------------------------------------------------ families

// FamilySwitch is one switch on a family's page: what the controls say,
// the family's own choice (nil = as the controls say) and what it gets.
type FamilySwitch struct {
	Key  string `json:"key"`
	Mode string `json:"mode"`
	Own  *bool  `json:"own"`
}

// Family returns the family's own switches.
func (s *ControlsService) Family(ctx context.Context, parentID string) ([]FamilySwitch, error) {
	own, err := s.accounts.Features(ctx, parentID)
	if err != nil {
		return nil, err
	}
	c := s.Controls(ctx)
	out := []FamilySwitch{}
	add := func(key, mode string) {
		sw := FamilySwitch{Key: key, Mode: mode}
		if v, ok := own[key]; ok {
			sw.Own = &v
		}
		out = append(out, sw)
	}
	for _, f := range domain.Features {
		add(f.ID, c.Features[f.ID])
	}
	for _, e := range domain.StoryEpisodes {
		add("story."+e.ID, c.Stories.Episodes[e.ID])
	}
	return out, nil
}

// SetFamily changes the family's own switches: key -> true/false, or nil
// to follow the controls again. Other keys stay.
func (s *ControlsService) SetFamily(ctx context.Context, by Actor, parentID string, changes map[string]*bool) ([]FamilySwitch, error) {
	own, err := s.accounts.Features(ctx, parentID)
	if err != nil {
		return nil, err
	}
	for k, v := range changes {
		if !domain.ValidOverrideKey(k) {
			return nil, domain.Invalid("unknown switch " + k)
		}
		if v == nil {
			delete(own, k)
		} else {
			own[k] = *v
		}
	}
	// keys of switches that no longer exist are dropped
	for k := range own {
		if !domain.ValidOverrideKey(k) {
			delete(own, k)
		}
	}
	if err := s.accounts.SetFeatures(ctx, parentID, own); err != nil {
		return nil, err
	}
	_ = s.admin.Audit(ctx, auditEntry(by, "family.features", parentID, map[string]any{"changes": changes}))
	return s.Family(ctx, parentID)
}
