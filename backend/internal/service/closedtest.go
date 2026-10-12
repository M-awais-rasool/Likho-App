package service

import (
	"context"
	"log/slog"
	"net/url"
	"slices"
	"strings"
	"sync"
	"time"
	_ "time/tzdata" // the test's time zone, also on images without zoneinfo
	"unicode/utf8"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ClosedTestService runs the Google Play closed test in the admin panel:
// the testers, whose Likho account is whose, and the days each of them
// used the app. Nothing new is collected from the phone: a day counts when
// the account talks to the API (activity tracking, at most every few
// minutes), in the test's time zone.
//
// Only testers can install a closed-test build, so while the test is set
// up every account that uses the app is treated as a tester: it is linked
// to the tester with the same email (when there is one) and gets Likho
// Plus and every level open, as the settings say. An account the team
// marks as not a tester (e.g. their own phone) gets nothing.
type ClosedTestService struct {
	repo     *repository.ClosedTestRepository
	accounts *repository.AccountRepository
	admin    *repository.AdminRepository
	cache    *cache.Cache
	ttl      time.Duration

	mu    sync.Mutex
	cfg   ClosedTestSettings
	cfgAt time.Time
}

func NewClosedTestService(repo *repository.ClosedTestRepository, accounts *repository.AccountRepository, admin *repository.AdminRepository, c *cache.Cache) *ClosedTestService {
	return &ClosedTestService{repo: repo, accounts: accounts, admin: admin, cache: c, ttl: 30 * time.Second}
}

// ClosedTestSettings are set in the panel.
type ClosedTestSettings struct {
	StartDate  string `json:"startDate"`  // the first day, YYYY-MM-DD ("" = no test set up)
	Days       int    `json:"days"`       // how long it runs (Play: 14 days)
	Needed     int    `json:"needed"`     // testers Play needs (12)
	TimeZone   string `json:"timeZone"`   // where the days are counted, e.g. Asia/Karachi
	Plus       bool   `json:"plus"`       // testers get Likho Plus…
	PlusUntil  string `json:"plusUntil"`  // …until the end of this day (YYYY-MM-DD)
	OpenLevels bool   `json:"openLevels"` // testers can play any level
	OptInURL   string `json:"optInUrl"`   // Play's link to join the test (for the invite)
	Reminder   string `json:"reminder"`   // WhatsApp reminder: {name}, {day} and {days} are filled in
}

var DefaultClosedTestSettings = ClosedTestSettings{
	Days: 14, Needed: 12, TimeZone: "Asia/Karachi", Plus: true, OpenLevels: true,
	Reminder: "Hi {name}! Please open Likho for a minute today. It counts for our Google Play test (day {day} of {days}). Thank you!",
}

const (
	closedTestKey = "closed_test"
	dateLayout    = "2006-01-02"
)

// Settings returns the settings (read at most every 30 s).
func (s *ClosedTestService) Settings(ctx context.Context) ClosedTestSettings {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.cfgAt.IsZero() && time.Since(s.cfgAt) < s.ttl {
		return s.cfg
	}
	c := DefaultClosedTestSettings
	if _, err := s.admin.Setting(ctx, closedTestKey, &c); err != nil {
		slog.Warn("closed test settings", "err", err)
	}
	s.cfg, s.cfgAt = c, time.Now()
	return c
}

// testWindow is the test in its time zone. Days are dates at midnight UTC
// (as date columns read back).
type testWindow struct {
	loc               *time.Location
	today, start, end time.Time
}

// window returns the test's days; false when no test is set up.
func (c ClosedTestSettings) window(now time.Time) (testWindow, bool) {
	loc, err := time.LoadLocation(c.TimeZone)
	if err != nil {
		loc = time.UTC
	}
	y, m, d := now.In(loc).Date()
	w := testWindow{loc: loc, today: time.Date(y, m, d, 0, 0, 0, 0, time.UTC)}
	start, err := time.Parse(dateLayout, c.StartDate)
	if err != nil {
		return w, false
	}
	w.start, w.end = start, start.AddDate(0, 0, c.Days-1)
	return w, true
}

// plusEnd is when the testers' Plus ends: the end of PlusUntil in the
// test's time zone (30 days after the test when not set).
func (c ClosedTestSettings) plusEnd(w testWindow) time.Time {
	day, err := time.Parse(dateLayout, c.PlusUntil)
	if err != nil {
		day = w.end.AddDate(0, 0, 30)
	}
	return time.Date(day.Year(), day.Month(), day.Day()+1, 0, 0, 0, 0, w.loc)
}

// recording: days are recorded (and perks given) from the moment the test
// is set up until its last day.
func (c ClosedTestSettings) recording(now time.Time) (testWindow, bool) {
	w, ok := c.window(now)
	return w, ok && !w.today.After(w.end)
}

// Seen is told (at most every few minutes) that the account uses the app.
// The first time each day it also links the account by email and gives
// the testers' perks. Never fails a request: problems are only logged.
func (s *ClosedTestService) Seen(ctx context.Context, parentID string) {
	cfg := s.Settings(ctx)
	w, ok := cfg.recording(time.Now())
	if !ok {
		return
	}
	first, err := s.repo.AddDay(ctx, parentID, w.today)
	if err != nil {
		slog.Warn("closed test: day", "parent", parentID, "err", err)
		return
	}
	if !first {
		return
	}
	link, found, err := s.repo.Link(ctx, parentID)
	if err != nil {
		slog.Warn("closed test: link", "parent", parentID, "err", err)
		return
	}
	if !found {
		if p, err := s.accounts.Get(ctx, parentID); err == nil {
			s.linkByEmail(ctx, []repository.TestAccountRow{{ParentID: p.ID, Email: p.Email}})
		}
	} else if link.TesterID == nil {
		return // not a tester
	}
	s.givePerks(ctx, cfg, w, parentID)
}

func (s *ClosedTestService) givePerks(ctx context.Context, cfg ClosedTestSettings, w testWindow, parentID string) {
	var until *time.Time
	if cfg.Plus {
		t := cfg.plusEnd(w)
		until = &t
	}
	changed, err := s.repo.GivePerks(ctx, parentID, until, cfg.OpenLevels)
	if err != nil {
		slog.Warn("closed test: perks", "parent", parentID, "err", err)
	}
	if changed {
		s.cache.ForgetMe(ctx, parentID)
	}
}

// linkByEmail links each of [accounts] (nobody said whose yet) to the
// tester with the same email, if there is one.
func (s *ClosedTestService) linkByEmail(ctx context.Context, accounts []repository.TestAccountRow) {
	if len(accounts) == 0 {
		return
	}
	testers, err := s.repo.Testers(ctx)
	if err != nil {
		slog.Warn("closed test: testers", "err", err)
		return
	}
	byEmail := map[string]string{}
	for _, t := range testers {
		if e := normalizeEmail(t.Email); e != "" {
			byEmail[e] = t.ID
		}
	}
	for _, a := range accounts {
		if id, ok := byEmail[normalizeEmail(a.Email)]; ok {
			if err := s.repo.SetLink(ctx, a.ParentID, &id, true); err != nil {
				slog.Warn("closed test: link by email", "parent", a.ParentID, "err", err)
			}
		}
	}
}

// normalizeEmail makes the same Google account's spellings equal: case,
// and for Gmail the dots and a "+tag" in the name.
func normalizeEmail(e string) string {
	e = strings.ToLower(strings.TrimSpace(e))
	at := strings.LastIndexByte(e, '@')
	if at <= 0 {
		return ""
	}
	name, domainPart := e[:at], e[at+1:]
	if domainPart == "gmail.com" || domainPart == "googlemail.com" {
		name, _, _ = strings.Cut(name, "+")
		name = strings.ReplaceAll(name, ".", "")
		domainPart = "gmail.com"
	}
	return name + "@" + domainPart
}

// ----------------------------------------------------------------- panel

// ClosedTestBoard is the panel's page: every tester with their accounts
// and days, and the accounts nobody has said whose they are yet.
type ClosedTestBoard struct {
	Settings   ClosedTestSettings          `json:"settings"`
	Today      string                      `json:"today"`   // in the test's time zone
	EndDate    string                      `json:"endDate"` // the last day ("" = no test set up)
	Day        int                         `json:"day"`     // today is day n (0 = not started, > days = over)
	Testers    []TesterRow                 `json:"testers"`
	New        []repository.TestAccountRow `json:"newAccounts"`
	NotTesters []repository.TestAccountRow `json:"notTesters"`
}

// TesterRow is a tester, their accounts and the days they used the app
// (on any of them).
type TesterRow struct {
	model.ClosedTester
	Accounts []repository.TestAccountRow `json:"accounts"`
	Days     []string                    `json:"days"`
}

func (s *ClosedTestService) Board(ctx context.Context) (ClosedTestBoard, error) {
	cfg := s.Settings(ctx)
	w, ok := cfg.window(time.Now())
	out := ClosedTestBoard{
		Settings: cfg, Today: w.today.Format(dateLayout),
		Testers: []TesterRow{}, New: []repository.TestAccountRow{}, NotTesters: []repository.TestAccountRow{},
	}
	if ok {
		out.EndDate = w.end.Format(dateLayout)
		out.Day = max(int(w.today.Sub(w.start).Hours()/24)+1, 0)
	}
	testers, err := s.repo.Testers(ctx)
	if err != nil {
		return out, err
	}
	accounts, err := s.repo.Accounts(ctx)
	if err != nil {
		return out, err
	}
	days, err := s.repo.Days(ctx)
	if err != nil {
		return out, err
	}
	daysOf := map[string][]string{}
	for _, d := range days {
		daysOf[d.ParentID] = append(daysOf[d.ParentID], d.Day.Format(dateLayout))
	}
	rows := make(map[string]*TesterRow, len(testers))
	for _, t := range testers {
		out.Testers = append(out.Testers, TesterRow{ClosedTester: t, Accounts: []repository.TestAccountRow{}, Days: []string{}})
	}
	for i := range out.Testers {
		rows[out.Testers[i].ID] = &out.Testers[i]
	}
	for _, a := range accounts {
		a.Days = nonNil(daysOf[a.ParentID])
		switch {
		case a.Linked && a.TesterID != nil && rows[*a.TesterID] != nil:
			t := rows[*a.TesterID]
			t.Accounts = append(t.Accounts, a)
			t.Days = append(t.Days, a.Days...)
		case a.Linked && a.TesterID == nil:
			out.NotTesters = append(out.NotTesters, a)
		default:
			out.New = append(out.New, a)
		}
	}
	for i := range out.Testers {
		slices.Sort(out.Testers[i].Days)
		out.Testers[i].Days = slices.Compact(out.Testers[i].Days)
	}
	return out, nil
}

// SetSettings saves the settings and gives (or takes back) the perks of
// the accounts already in the test.
func (s *ClosedTestService) SetSettings(ctx context.Context, by Actor, in ClosedTestSettings) (ClosedTestSettings, error) {
	c, err := in.clean()
	if err != nil {
		return in, err
	}
	if err := s.admin.SetSetting(ctx, closedTestKey, c); err != nil {
		return c, err
	}
	s.mu.Lock()
	s.cfg, s.cfgAt = c, time.Now()
	s.mu.Unlock()
	s.audit(ctx, by, "closed_test.settings", "closed_test", c)

	ids, err := s.repo.TesterAccounts(ctx)
	if err != nil {
		return c, err
	}
	changed, err := s.repo.SetOpenLevels(ctx, ids, c.OpenLevels && c.StartDate != "")
	if err != nil {
		return c, err
	}
	for _, id := range changed {
		s.cache.ForgetMe(ctx, id)
	}
	if w, ok := c.window(time.Now()); ok && c.Plus {
		for _, id := range ids {
			s.givePerks(ctx, ClosedTestSettings{Plus: true, PlusUntil: c.PlusUntil}, w, id)
		}
	}
	return c, nil
}

func (in ClosedTestSettings) clean() (ClosedTestSettings, error) {
	c := in
	c.StartDate, c.PlusUntil = strings.TrimSpace(c.StartDate), strings.TrimSpace(c.PlusUntil)
	c.TimeZone, c.OptInURL, c.Reminder = strings.TrimSpace(c.TimeZone), strings.TrimSpace(c.OptInURL), strings.TrimSpace(c.Reminder)
	if c.Days < 1 || c.Days > 90 {
		return c, domain.Invalid("days must be 1 to 90")
	}
	if c.Needed < 1 || c.Needed > 500 {
		return c, domain.Invalid("needed must be 1 to 500")
	}
	if c.TimeZone == "" {
		c.TimeZone = DefaultClosedTestSettings.TimeZone
	}
	if _, err := time.LoadLocation(c.TimeZone); err != nil || c.TimeZone == "Local" {
		return c, domain.Invalid("unknown time zone (e.g. Asia/Karachi)")
	}
	if c.StartDate != "" {
		start, err := time.Parse(dateLayout, c.StartDate)
		if err != nil {
			return c, domain.Invalid("startDate must be YYYY-MM-DD")
		}
		if c.PlusUntil == "" {
			c.PlusUntil = start.AddDate(0, 0, c.Days-1+30).Format(dateLayout)
		}
		until, err := time.Parse(dateLayout, c.PlusUntil)
		if err != nil {
			return c, domain.Invalid("plusUntil must be YYYY-MM-DD")
		}
		if until.Before(start) {
			return c, domain.Invalid("plusUntil must be on or after the start")
		}
	} else if c.PlusUntil != "" {
		if _, err := time.Parse(dateLayout, c.PlusUntil); err != nil {
			return c, domain.Invalid("plusUntil must be YYYY-MM-DD")
		}
	}
	if c.OptInURL != "" {
		u, err := url.Parse(c.OptInURL)
		if err != nil || u.Scheme != "https" || u.Host == "" || len(c.OptInURL) > 300 {
			return c, domain.Invalid("optInUrl must be an https link")
		}
	}
	if c.Reminder == "" {
		c.Reminder = DefaultClosedTestSettings.Reminder
	}
	if utf8.RuneCountInString(c.Reminder) > 500 {
		return c, domain.Invalid("reminder must be at most 500 characters")
	}
	return c, nil
}

// TesterIn is a tester as the panel sends it.
type TesterIn struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Phone string `json:"phone"`
	Note  string `json:"note"`
}

func (in TesterIn) clean() (model.ClosedTester, error) {
	t := model.ClosedTester{
		Name: strings.TrimSpace(in.Name), Email: strings.ToLower(strings.TrimSpace(in.Email)),
		Phone: whatsAppNumber(in.Phone), Note: strings.TrimSpace(in.Note),
	}
	if n := utf8.RuneCountInString(t.Name); n < 1 || n > 80 {
		return t, domain.Invalid("name must be 1 to 80 characters")
	}
	if t.Email != "" && (normalizeEmail(t.Email) == "" || len(t.Email) > 200 || strings.ContainsAny(t.Email, " ,;<>")) {
		return t, domain.Invalid("email is not valid: " + t.Email)
	}
	if strings.TrimSpace(in.Phone) != "" && (len(t.Phone) < 8 || len(t.Phone) > 15) {
		return t, domain.Invalid("phone must be a number with the country code, e.g. 923001234567")
	}
	if utf8.RuneCountInString(t.Note) > 200 {
		return t, domain.Invalid("note must be at most 200 characters")
	}
	return t, nil
}

// whatsAppNumber keeps the digits of a phone number in the international
// form WhatsApp links use (no +). A Pakistani mobile written the local
// way (03xx…) gets its country code.
func whatsAppNumber(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	d := b.String()
	switch {
	case strings.HasPrefix(d, "00"):
		d = d[2:]
	case len(d) == 11 && strings.HasPrefix(d, "03"):
		d = "92" + d[1:]
	}
	return d
}

// AddTesters adds testers (a pasted list); one whose email is already
// there is skipped. Accounts already seen with a tester's email are linked.
func (s *ClosedTestService) AddTesters(ctx context.Context, by Actor, in []TesterIn) (added []model.ClosedTester, skipped int, err error) {
	if len(in) == 0 || len(in) > 200 {
		return nil, 0, domain.Invalid("send 1 to 200 testers")
	}
	existing, err := s.repo.Testers(ctx)
	if err != nil {
		return nil, 0, err
	}
	seen := map[string]bool{}
	for _, t := range existing {
		seen[normalizeEmail(t.Email)] = true
	}
	for _, x := range in {
		t, err := x.clean()
		if err != nil {
			return nil, 0, err
		}
		if e := normalizeEmail(t.Email); e != "" {
			if seen[e] {
				skipped++
				continue
			}
			seen[e] = true
		}
		added = append(added, t)
	}
	if err := s.repo.CreateTesters(ctx, added); err != nil {
		return nil, 0, err
	}
	s.audit(ctx, by, "closed_test.testers_added", "", map[string]any{"added": len(added), "skipped": skipped})
	s.linkNew(ctx)
	return nonNil(added), skipped, nil
}

// linkNew links the accounts nobody has said whose they are by email.
func (s *ClosedTestService) linkNew(ctx context.Context) {
	accounts, err := s.repo.Accounts(ctx)
	if err != nil {
		slog.Warn("closed test: accounts", "err", err)
		return
	}
	s.linkByEmail(ctx, slices.DeleteFunc(accounts, func(a repository.TestAccountRow) bool { return a.Linked }))
}

func (s *ClosedTestService) UpdateTester(ctx context.Context, by Actor, id string, in TesterIn) (model.ClosedTester, error) {
	t, err := in.clean()
	if err != nil {
		return t, err
	}
	out, err := s.repo.UpdateTester(ctx, id, map[string]any{"name": t.Name, "email": t.Email, "phone": t.Phone, "note": t.Note})
	if err != nil {
		return out, err
	}
	s.audit(ctx, by, "closed_test.tester_updated", id, map[string]any{"name": t.Name, "email": t.Email})
	s.linkNew(ctx)
	return out, nil
}

func (s *ClosedTestService) DeleteTester(ctx context.Context, by Actor, id string) error {
	t, err := s.repo.Tester(ctx, id)
	if err != nil {
		return err
	}
	if err := s.repo.DeleteTester(ctx, id); err != nil {
		return err
	}
	s.audit(ctx, by, "closed_test.tester_removed", id, map[string]any{"name": t.Name, "email": t.Email})
	return nil
}

// LinkAccount says whose the account is: [testerID]'s, or nobody's (nil:
// not a tester). A tester's account gets the testers' perks.
func (s *ClosedTestService) LinkAccount(ctx context.Context, by Actor, parentID string, testerID *string) error {
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return err
	}
	name := ""
	if testerID != nil {
		t, err := s.repo.Tester(ctx, *testerID)
		if err != nil {
			return err
		}
		name = t.Name
	}
	if err := s.repo.SetLink(ctx, parentID, testerID, false); err != nil {
		return err
	}
	s.audit(ctx, by, "closed_test.account_linked", parentID, map[string]any{"email": p.Email, "tester": name})
	cfg := s.Settings(ctx)
	if w, ok := cfg.recording(time.Now()); ok && testerID != nil {
		s.givePerks(ctx, cfg, w, parentID)
	}
	return nil
}

// UnlinkAccount forgets whose the account is (it is listed as new again).
func (s *ClosedTestService) UnlinkAccount(ctx context.Context, by Actor, parentID string) error {
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return err
	}
	if err := s.repo.Unlink(ctx, parentID); err != nil {
		return err
	}
	s.audit(ctx, by, "closed_test.account_unlinked", parentID, map[string]any{"email": p.Email})
	return nil
}

func (s *ClosedTestService) audit(ctx context.Context, by Actor, action, target string, detail any) {
	_ = s.admin.Audit(ctx, auditEntry(by, action, target, detail))
}
