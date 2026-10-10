package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"path"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"likho/backend/internal/catalog"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ContentService: writing levels in the admin panel. New levels and edits
// of the built-in ones are stored in the database and laid over the files
// in content/ (catalog.Overlay), so they are checked by exactly the same
// rules. Each has a working copy (what the panel edits and previews) and a
// live copy (what phones get). Publishing checks the whole course with the
// new live copy, then swaps the served catalog without a restart; other
// API servers notice the new content revision and reload too.
type ContentService struct {
	base     fs.FS
	served   catalog.Options
	store    *catalog.Store
	repo     *repository.ContentRepository
	admin    *repository.AdminRepository
	insights *repository.InsightsRepository

	mu       sync.Mutex
	rev      int64
	problems []string // why the live content could not be served (the last good one is)
	builtin  *catalog.Catalog
}

func NewContentService(base fs.FS, served catalog.Options, store *catalog.Store, repo *repository.ContentRepository,
	admin *repository.AdminRepository, insights *repository.InsightsRepository) *ContentService {
	s := &ContentService{base: base, served: served, store: store, repo: repo, admin: admin, insights: insights}
	if c, err := catalog.Load(base, catalog.Options{IncludeDrafts: true}); err == nil {
		s.builtin = c
	} else {
		slog.Error("content: built-in content does not load", "err", err)
	}
	return s
}

// ProblemsError lists what is wrong with content (each with its file).
type ProblemsError struct{ Problems []string }

func (e *ProblemsError) Error() string { return strings.Join(e.Problems, "\n") }

func problemsOf(err error, courseDir string) *ProblemsError {
	var out []string
	for _, line := range strings.Split(err.Error(), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "content has ") {
			continue
		}
		if courseDir != "" {
			line = strings.ReplaceAll(line, courseDir+"/", "")
		}
		out = append(out, line)
	}
	return &ProblemsError{Problems: out}
}

// --------------------------------------------------------------- loading

type contentRows struct {
	levels []model.ContentLevel
	worlds []model.ContentWorld
}

func (s *ContentService) rows(ctx context.Context) (contentRows, error) {
	l, err := s.repo.Levels(ctx, "")
	if err != nil {
		return contentRows{}, err
	}
	w, err := s.repo.Worlds(ctx, "")
	return contentRows{levels: l, worlds: w}, err
}

func worldFile(courseID, folder string) string {
	return path.Join("courses", courseID, "worlds", folder, "world.json")
}

// files lays out the rows as content files: the live copies ([live]) or the
// working copies. A world added in the panel is only included once it has a
// level (a world needs one).
func (r contentRows) files(live bool) map[string][]byte {
	out := map[string][]byte{}
	used := map[string]bool{}
	for _, l := range r.levels {
		doc := l.Doc
		if live {
			if l.LiveDoc == nil {
				continue
			}
			doc = *l.LiveDoc
		}
		out[l.File] = []byte(doc)
		used[l.CourseID+"/"+l.World] = true
	}
	for _, w := range r.worlds {
		if used[w.CourseID+"/"+w.Folder] {
			out[worldFile(w.CourseID, w.Folder)] = []byte(w.Doc)
		}
	}
	return out
}

func (s *ContentService) load(files map[string][]byte, staged bool) (*catalog.Catalog, error) {
	opt := s.served
	if staged {
		opt.IncludeDrafts = true
	}
	return catalog.Load(catalog.Overlay(s.base, files), opt)
}

// Reload serves the live content from the database. When it has problems
// the catalog being served is kept and the problems are reported in the
// panel.
func (s *ContentService) Reload(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.reload(ctx)
}

func (s *ContentService) reload(ctx context.Context) error {
	rev, err := s.revision(ctx)
	if err != nil {
		return err
	}
	rows, err := s.rows(ctx)
	if err != nil {
		return err
	}
	cat, err := s.load(rows.files(true), false)
	s.rev = rev
	if err != nil {
		s.problems = problemsOf(err, "").Problems
		slog.Error("content: published content has problems; serving the last good content", "err", err)
		return err
	}
	s.problems = nil
	s.store.Set(cat)
	for _, c := range cat.Courses() {
		slog.Info("content: course served", "id", c.Summary.ID, "levels", c.Stats.Levels, "version", c.Summary.Version)
	}
	return nil
}

const contentRevKey = "content"

type contentRev struct {
	Rev int64 `json:"rev"`
}

func (s *ContentService) revision(ctx context.Context) (int64, error) {
	var r contentRev
	_, err := s.admin.Setting(ctx, contentRevKey, &r)
	return r.Rev, err
}

// changed tells every API server that the live content changed.
func (s *ContentService) changed(ctx context.Context) error {
	rev, err := s.revision(ctx)
	if err != nil {
		return err
	}
	if err := s.admin.SetSetting(ctx, contentRevKey, contentRev{Rev: rev + 1}); err != nil {
		return err
	}
	return s.reload(ctx)
}

// Watch reloads the content when another server published (checked every
// [every]) until [ctx] ends.
func (s *ContentService) Watch(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			rev, err := s.revision(ctx)
			if err != nil {
				continue
			}
			s.mu.Lock()
			if rev != s.rev {
				_ = s.reload(ctx)
			}
			s.mu.Unlock()
		}
	}
}

// Problems are why the published content could not be served (none = ok).
func (s *ContentService) Problems() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string{}, s.problems...)
}

// Revision is the content revision this server serves.
func (s *ContentService) Revision() int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.rev
}

// ----------------------------------------------------------------- views

// Known values the app understands (see the app's LikhoWorlds, BossFigure).
var (
	WorldThemes = []string{"letterLand", "smallLetterCove", "phonicsForest", "wordTown", "sentenceSky", "storySpace",
		"soundMountain", "blendBeach", "sightGarden", "actionJungle", "questionIsland", "readingRiver", "alphabetCastle", "frostyBay"}
	WorldBosses = []string{"snail", "fish", "bear", "robotBus", "cloud", "moon", "goat", "crab", "ladybug", "monkey", "turtle", "frog",
		"dragon", "penguin"}
)

type ContentCourse struct {
	ID          string                `json:"id"`
	Title       string                `json:"title"`
	Version     string                `json:"version"`    // served to phones
	LiveLevels  int                   `json:"liveLevels"` // levels phones get
	NextNumber  int                   `json:"nextNumber"` // number of a new level
	Revision    int64                 `json:"revision"`   // content revision
	Problems    []string              `json:"problems"`   // live content problems
	Worlds      []ContentWorldView    `json:"worlds"`
	Levels      []ContentLevelView    `json:"levels"`
	Themes      []string              `json:"themes"`
	Bosses      []string              `json:"bosses"`
	EmptyWorlds []ContentWorldView    `json:"emptyWorlds"` // added in the panel, no level yet
	Courses     []model.CourseSummary `json:"courses"`
}

type ContentWorldView struct {
	Folder   string `json:"folder"`
	ID       string `json:"id"`
	Order    int    `json:"order"`
	Name     string `json:"name"`
	Skill    string `json:"skill"`
	Icon     string `json:"icon"`
	ThemeID  string `json:"themeId"`
	BossID   string `json:"bossId"`
	BossName string `json:"bossName"`
	Source   string `json:"source"` // builtin | admin
	Live     bool   `json:"live"`
	Levels   []int  `json:"levels"`
}

type ContentLevelView struct {
	Number               int        `json:"number"`
	ID                   string     `json:"id"`
	Name                 string     `json:"name"`
	Skill                string     `json:"skill"`
	Icon                 string     `json:"icon"`
	World                string     `json:"world"` // folder
	WorldID              string     `json:"worldId"`
	IsBoss               bool       `json:"isBoss"`
	RequiresSubscription bool       `json:"requiresSubscription"`
	Rounds               int        `json:"rounds"`
	Source               string     `json:"source"` // builtin | edited | new
	Status               string     `json:"status"` // live | draft | changed
	UpdatedAt            *time.Time `json:"updatedAt"`
	UpdatedBy            string     `json:"updatedBy"`
	PublishedAt          *time.Time `json:"publishedAt"`
}

type ContentLevelDetail struct {
	ContentLevelView
	Doc        string  `json:"doc"`        // working copy
	LiveDoc    *string `json:"liveDoc"`    // what phones get (nil = not live)
	BuiltinDoc *string `json:"builtinDoc"` // the file in content/, for an edited built-in level
}

func statusOf(row *model.ContentLevel) string {
	switch {
	case row == nil:
		return "live"
	case row.LiveDoc == nil && !row.Builtin:
		return "draft"
	case row.LiveDoc != nil && *row.LiveDoc == row.Doc:
		return "live"
	default:
		return "changed"
	}
}

func sourceOf(row *model.ContentLevel) string {
	switch {
	case row == nil:
		return "builtin"
	case row.Builtin:
		return "edited"
	default:
		return "new"
	}
}

// staged loads the working copies (what the panel shows and previews).
func (s *ContentService) staged(ctx context.Context) (*catalog.Catalog, contentRows, error) {
	rows, err := s.rows(ctx)
	if err != nil {
		return nil, rows, err
	}
	cat, err := s.load(rows.files(false), true)
	return cat, rows, err
}

func (s *ContentService) course(cat *catalog.Catalog, id string) (*catalog.Course, error) {
	c, ok := cat.Course(id)
	if !ok {
		return nil, domain.ErrCourseNotFound
	}
	return c, nil
}

// Course describes a course for the content page.
func (s *ContentService) Course(ctx context.Context, id string) (ContentCourse, error) {
	cat, rows, err := s.staged(ctx)
	if err != nil {
		return ContentCourse{}, problemsOf(err, "")
	}
	c, err := s.course(cat, id)
	if err != nil {
		return ContentCourse{}, err
	}
	out := ContentCourse{
		ID: id, Title: c.Summary.Title, NextNumber: c.LastLevel() + 1, Revision: s.Revision(), Problems: s.Problems(),
		Themes: WorldThemes, Bosses: WorldBosses, Worlds: []ContentWorldView{}, Levels: []ContentLevelView{}, EmptyWorlds: []ContentWorldView{},
	}
	for _, sc := range s.store.Get().Courses() {
		out.Courses = append(out.Courses, sc.Summary)
	}
	if live, ok := s.store.Get().Course(id); ok {
		out.Version, out.LiveLevels = live.Summary.Version, live.LastLevel()
	}
	byNumber := map[int]*model.ContentLevel{}
	for i := range rows.levels {
		if l := &rows.levels[i]; l.CourseID == id {
			byNumber[l.Number] = l
		}
	}
	adminWorld := map[string]bool{}
	for _, w := range rows.worlds {
		if w.CourseID == id {
			adminWorld[w.Folder] = true
		}
	}
	liveWorld := map[string]bool{}
	if live, ok := s.store.Get().Course(id); ok {
		for _, w := range live.Worlds {
			liveWorld[w.Folder] = true
		}
	}
	shown := map[string]bool{}
	for _, w := range c.Worlds {
		src := "builtin"
		if adminWorld[w.Folder] {
			src = "admin"
		}
		shown[w.Folder] = true
		out.Worlds = append(out.Worlds, ContentWorldView{
			Folder: w.Folder, ID: w.ID, Order: w.Order, Name: w.Name, Skill: w.Skill, Icon: w.Icon, ThemeID: w.ThemeID,
			BossID: w.BossID, BossName: w.BossName, Source: src, Live: liveWorld[w.Folder], Levels: nonNil(w.Levels),
		})
	}
	for _, w := range rows.worlds {
		if w.CourseID != id || shown[w.Folder] {
			continue
		}
		v, err := worldView(w)
		if err != nil {
			continue
		}
		out.EmptyWorlds = append(out.EmptyWorlds, v)
	}
	folderOf := map[string]string{}
	for _, w := range c.Worlds {
		folderOf[w.ID] = w.Folder
	}
	for _, l := range c.Levels() {
		row := byNumber[l.Number]
		v := ContentLevelView{
			Number: l.Number, ID: l.ID, Name: l.Name, Skill: l.Skill, Icon: l.Icon, World: folderOf[l.WorldID], WorldID: l.WorldID,
			IsBoss: l.IsBoss, RequiresSubscription: l.RequiresSubscription, Rounds: l.Rounds,
			Source: sourceOf(row), Status: statusOf(row),
		}
		if row != nil {
			v.UpdatedAt, v.UpdatedBy, v.PublishedAt = &row.UpdatedAt, row.UpdatedBy, row.PublishedAt
		}
		out.Levels = append(out.Levels, v)
	}
	return out, nil
}

func worldView(w model.ContentWorld) (ContentWorldView, error) {
	var d struct {
		ID, Name, Skill, Icon, ThemeID string
		Order                          int
		Boss                           struct{ ID, Name string }
	}
	if err := json.Unmarshal([]byte(w.Doc), &d); err != nil {
		return ContentWorldView{}, err
	}
	return ContentWorldView{Folder: w.Folder, ID: d.ID, Order: d.Order, Name: d.Name, Skill: d.Skill, Icon: d.Icon,
		ThemeID: d.ThemeID, BossID: d.Boss.ID, BossName: d.Boss.Name, Source: "admin", Levels: []int{}}, nil
}

// Level returns a level with its working, live and built-in copies.
func (s *ContentService) Level(ctx context.Context, courseID string, number int) (ContentLevelDetail, error) {
	course, err := s.Course(ctx, courseID)
	if err != nil {
		return ContentLevelDetail{}, err
	}
	var view *ContentLevelView
	for i := range course.Levels {
		if course.Levels[i].Number == number {
			view = &course.Levels[i]
		}
	}
	if view == nil {
		return ContentLevelDetail{}, domain.ErrNotFound
	}
	out := ContentLevelDetail{ContentLevelView: *view}
	builtin := s.builtinLevel(courseID, number)
	if builtin != nil {
		doc := string(builtin.Doc)
		out.BuiltinDoc = &doc
	}
	row, err := s.repo.Level(ctx, courseID, number)
	switch {
	case err == nil:
		out.Doc, out.LiveDoc = row.Doc, row.LiveDoc
		if row.Builtin && row.LiveDoc == nil {
			out.LiveDoc = out.BuiltinDoc
		}
		if !row.Builtin {
			out.BuiltinDoc = nil
		}
	case errors.Is(err, domain.ErrNotFound) && builtin != nil:
		out.Doc, out.LiveDoc = *out.BuiltinDoc, out.BuiltinDoc
	default:
		return ContentLevelDetail{}, err
	}
	return out, nil
}

func (s *ContentService) builtinLevel(courseID string, number int) *catalog.Level {
	if s.builtin == nil {
		return nil
	}
	c, ok := s.builtin.Course(courseID)
	if !ok {
		return nil
	}
	l, ok := c.Level(number)
	if !ok {
		return nil
	}
	return &l
}

// StagedDocument is the course as phones would get it with every working
// copy published (for the preview).
func (s *ContentService) StagedDocument(ctx context.Context, courseID string) ([]byte, error) {
	cat, _, err := s.staged(ctx)
	if err != nil {
		return nil, problemsOf(err, "")
	}
	c, err := s.course(cat, courseID)
	if err != nil {
		return nil, err
	}
	return c.JSON, nil
}

// ---------------------------------------------------------------- checks

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(s string) string {
	s = strings.Trim(nonSlug.ReplaceAllString(strings.ToLower(s), "-"), "-")
	if len(s) > 40 {
		s = strings.Trim(s[:40], "-")
	}
	if s == "" {
		s = "level"
	}
	return s
}

// levelHead is what a level document must say about itself.
type levelHead struct {
	ID     string `json:"id"`
	Number *int   `json:"number"`
	Name   string `json:"name"`
}

func parseLevel(doc string, number int) (levelHead, string, error) {
	doc = strings.TrimSpace(doc)
	var h levelHead
	if err := json.Unmarshal([]byte(doc), &h); err != nil {
		return h, "", &ProblemsError{Problems: []string{"not valid JSON: " + err.Error()}}
	}
	if h.Number == nil || *h.Number != number {
		return h, "", &ProblemsError{Problems: []string{fmt.Sprintf(`"number" must be %d`, number)}}
	}
	var pretty bytes.Buffer
	if err := json.Indent(&pretty, []byte(doc), "", "  "); err != nil {
		return h, "", &ProblemsError{Problems: []string{err.Error()}}
	}
	pretty.WriteByte('\n')
	return h, pretty.String(), nil
}

// where finds the file of level [number]: its row, the built-in file, or a
// new file in world [folder].
func (s *ContentService) where(ctx context.Context, courseID string, number int, folder, name string) (file, world string, row *model.ContentLevel, builtin bool, err error) {
	r, err := s.repo.Level(ctx, courseID, number)
	if err == nil {
		return r.File, r.World, &r, r.Builtin, nil
	}
	if !errors.Is(err, domain.ErrNotFound) {
		return "", "", nil, false, err
	}
	if b := s.builtinLevel(courseID, number); b != nil {
		dir := path.Dir(path.Dir(b.File)) // …/worlds/<folder>/levels/x.json
		return b.File, path.Base(dir), nil, true, nil
	}
	if folder == "" {
		return "", "", nil, false, domain.Invalid("world is required for a new level")
	}
	return path.Join("courses", courseID, "worlds", folder, "levels", fmt.Sprintf("%02d-%s.json", number, slugify(name))), folder, nil, false, nil
}

// Validate checks a level document as level [number] (in world [folder]
// when it is new) against the whole course: nil when it is fine.
func (s *ContentService) Validate(ctx context.Context, courseID string, number int, folder, doc string) error {
	_, err := s.check(ctx, courseID, number, folder, doc)
	return err
}

type checked struct {
	head    levelHead
	doc     string
	file    string
	world   string
	row     *model.ContentLevel
	builtin bool
	rows    contentRows
}

func (s *ContentService) check(ctx context.Context, courseID string, number int, folder, doc string) (checked, error) {
	if number < 1 {
		return checked{}, domain.Invalid("level number must be 1 or more")
	}
	h, pretty, err := parseLevel(doc, number)
	if err != nil {
		return checked{}, err
	}
	file, world, row, builtin, err := s.where(ctx, courseID, number, folder, h.Name)
	if err != nil {
		return checked{}, err
	}
	rows, err := s.rows(ctx)
	if err != nil {
		return checked{}, err
	}
	if row == nil && !builtin && !s.hasWorld(ctx, courseID, world, rows) {
		return checked{}, domain.Invalid(fmt.Sprintf("world %q does not exist", world))
	}
	files := rows.files(false)
	files[file] = []byte(pretty)
	for _, w := range rows.worlds {
		if w.CourseID == courseID && w.Folder == world {
			files[worldFile(courseID, world)] = []byte(w.Doc)
		}
	}
	if _, err := s.load(files, true); err != nil {
		return checked{}, problemsOf(err, path.Join("courses", courseID))
	}
	return checked{head: h, doc: pretty, file: file, world: world, row: row, builtin: builtin, rows: rows}, nil
}

func (s *ContentService) hasWorld(ctx context.Context, courseID, folder string, rows contentRows) bool {
	for _, w := range rows.worlds {
		if w.CourseID == courseID && w.Folder == folder {
			return true
		}
	}
	if s.builtin != nil {
		if c, ok := s.builtin.Course(courseID); ok {
			for _, w := range c.Worlds {
				if w.Folder == folder {
					return true
				}
			}
		}
	}
	return false
}

// --------------------------------------------------------------- changes

// SaveLevel saves a working copy: a new level ([number] = the next number,
// in world [folder]), or an edit of a level (a built-in level gets an
// edited copy). Nothing changes for phones until it is published.
func (s *ContentService) SaveLevel(ctx context.Context, courseID string, number int, folder, doc, by string) (ContentLevelDetail, error) {
	s.mu.Lock()
	ck, err := s.check(ctx, courseID, number, folder, doc)
	if err == nil {
		row := ck.row
		if row == nil {
			row = &model.ContentLevel{CourseID: courseID, Number: number, World: ck.world, File: ck.file, Builtin: ck.builtin, CreatedBy: by}
		}
		row.Doc, row.UpdatedBy = ck.doc, by
		err = s.repo.SaveLevel(ctx, row)
	}
	s.mu.Unlock()
	if err != nil {
		return ContentLevelDetail{}, err
	}
	return s.Level(ctx, courseID, number)
}

// Publish makes the working copy live: phones get it on their next start.
func (s *ContentService) Publish(ctx context.Context, courseID string, number int, by string) (ContentLevelDetail, error) {
	if err := s.publish(ctx, courseID, number, by); err != nil {
		return ContentLevelDetail{}, err
	}
	return s.Level(ctx, courseID, number)
}

func (s *ContentService) publish(ctx context.Context, courseID string, number int, by string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	row, err := s.repo.Level(ctx, courseID, number)
	if err != nil {
		return err
	}
	rows, err := s.rows(ctx)
	if err != nil {
		return err
	}
	for i := range rows.levels {
		if l := &rows.levels[i]; l.CourseID == courseID && l.Number == number {
			l.LiveDoc = &l.Doc
		}
	}
	if _, err := s.load(rows.files(true), false); err != nil {
		return problemsOf(err, path.Join("courses", courseID))
	}
	now := time.Now()
	row.LiveDoc, row.PublishedAt, row.UpdatedBy = &row.Doc, &now, by
	if err := s.repo.SaveLevel(ctx, &row); err != nil {
		return err
	}
	return s.changed(ctx)
}

// Unpublish takes a new level away from phones again. Only the last level
// can go (numbers have no gaps), and only before any child finished it.
func (s *ContentService) Unpublish(ctx context.Context, courseID string, number int) (ContentLevelDetail, error) {
	err := func() error {
		s.mu.Lock()
		defer s.mu.Unlock()
		row, err := s.repo.Level(ctx, courseID, number)
		if err != nil {
			return err
		}
		if row.Builtin {
			return domain.Invalid("a built-in level cannot be unpublished; revert it to the original instead")
		}
		if row.LiveDoc == nil {
			return domain.Invalid("this level is not published")
		}
		if live, ok := s.store.Get().Course(courseID); ok && live.LastLevel() != number {
			return domain.Invalid(fmt.Sprintf("only the last level (%d) can be unpublished", live.LastLevel()))
		}
		played, err := s.insights.LevelHasProgress(ctx, courseID, number)
		if err != nil {
			return err
		}
		if played {
			return domain.Invalid("children already finished this level, so it cannot be taken away")
		}
		row.LiveDoc = nil
		if err := s.repo.SaveLevel(ctx, &row); err != nil {
			return err
		}
		return s.changed(ctx)
	}()
	if err != nil {
		return ContentLevelDetail{}, err
	}
	return s.Level(ctx, courseID, number)
}

// Discard drops the working copy's changes (back to the live copy).
func (s *ContentService) Discard(ctx context.Context, courseID string, number int, by string) (ContentLevelDetail, error) {
	err := func() error {
		s.mu.Lock()
		defer s.mu.Unlock()
		row, err := s.repo.Level(ctx, courseID, number)
		if err != nil {
			return err
		}
		switch {
		case row.Builtin && row.LiveDoc == nil:
			return s.repo.DeleteLevel(ctx, courseID, number)
		case row.LiveDoc == nil:
			return domain.Invalid("this level was never published; delete it instead")
		}
		row.Doc, row.UpdatedBy = *row.LiveDoc, by
		return s.repo.SaveLevel(ctx, &row)
	}()
	if err != nil {
		return ContentLevelDetail{}, err
	}
	return s.Level(ctx, courseID, number)
}

// Delete removes a level written in the panel. An edited built-in level
// goes back to its original. A new level must not be live, and only the
// last one can go (numbers have no gaps).
func (s *ContentService) Delete(ctx context.Context, courseID string, number int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	row, err := s.repo.Level(ctx, courseID, number)
	if err != nil {
		return err
	}
	if row.Builtin {
		if err := s.repo.DeleteLevel(ctx, courseID, number); err != nil {
			return err
		}
		if row.LiveDoc != nil {
			return s.changed(ctx)
		}
		return nil
	}
	if row.LiveDoc != nil {
		return domain.Invalid("unpublish the level before deleting it")
	}
	rows, err := s.rows(ctx)
	if err != nil {
		return err
	}
	for _, l := range rows.levels {
		if l.CourseID == courseID && l.Number > number {
			return domain.Invalid(fmt.Sprintf("delete level %d first: levels are numbered without gaps", l.Number))
		}
	}
	return s.repo.DeleteLevel(ctx, courseID, number)
}

// WorldInput is a world added in the panel.
type WorldInput struct {
	Name     string `json:"name"`
	Skill    string `json:"skill"`
	Icon     string `json:"icon"`
	ThemeID  string `json:"themeId"`
	BossID   string `json:"bossId"`
	BossName string `json:"bossName"`
}

func (in WorldInput) check() error {
	switch {
	case strings.TrimSpace(in.Name) == "":
		return domain.Invalid("name is required")
	case strings.TrimSpace(in.Icon) == "":
		return domain.Invalid("icon is required")
	case !contains(WorldThemes, in.ThemeID):
		return domain.Invalid("themeId must be one of " + strings.Join(WorldThemes, ", "))
	case !contains(WorldBosses, in.BossID):
		return domain.Invalid("bossId must be one of " + strings.Join(WorldBosses, ", "))
	case strings.TrimSpace(in.BossName) == "":
		return domain.Invalid("bossName is required")
	}
	return nil
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func worldDoc(id string, order int, in WorldInput) string {
	doc := struct {
		ID      string `json:"id"`
		Order   int    `json:"order"`
		Name    string `json:"name"`
		Skill   string `json:"skill"`
		Icon    string `json:"icon"`
		ThemeID string `json:"themeId"`
		Boss    struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"boss"`
	}{ID: id, Order: order, Name: strings.TrimSpace(in.Name), Skill: strings.TrimSpace(in.Skill), Icon: strings.TrimSpace(in.Icon), ThemeID: in.ThemeID}
	doc.Boss.ID, doc.Boss.Name = in.BossID, strings.TrimSpace(in.BossName)
	b, _ := json.MarshalIndent(doc, "", "  ")
	return string(b) + "\n"
}

// CreateWorld adds a world after the last one. It shows on the map once
// one of its levels is published.
func (s *ContentService) CreateWorld(ctx context.Context, courseID string, in WorldInput, by string) (ContentWorldView, error) {
	if err := in.check(); err != nil {
		return ContentWorldView{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	cat, rows, err := s.staged(ctx)
	if err != nil {
		return ContentWorldView{}, problemsOf(err, "")
	}
	c, err := s.course(cat, courseID)
	if err != nil {
		return ContentWorldView{}, err
	}
	order := len(c.Worlds) + 1
	ids := map[string]bool{}
	for _, w := range c.Worlds {
		ids[w.ID] = true
	}
	for _, w := range rows.worlds {
		if w.CourseID != courseID {
			continue
		}
		if v, err := worldView(w); err == nil {
			ids[v.ID] = true
			if v.Order >= order {
				return ContentWorldView{}, domain.Invalid(fmt.Sprintf("world %q has no level yet: add levels to it first", v.Name))
			}
		}
	}
	id := fmt.Sprintf("world-%d", order)
	for n := 2; ids[id]; n++ {
		id = fmt.Sprintf("world-%d-%d", order, n)
	}
	w := model.ContentWorld{CourseID: courseID, Folder: fmt.Sprintf("%02d-%s", order, slugify(in.Name)), Order: order, Doc: worldDoc(id, order, in), CreatedBy: by}
	if err := s.repo.SaveWorld(ctx, &w); err != nil {
		return ContentWorldView{}, err
	}
	return worldView(w)
}

// UpdateWorld changes a world added in the panel (live at once when it
// already has published levels).
func (s *ContentService) UpdateWorld(ctx context.Context, courseID, folder string, in WorldInput) (ContentWorldView, error) {
	if err := in.check(); err != nil {
		return ContentWorldView{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.rows(ctx)
	if err != nil {
		return ContentWorldView{}, err
	}
	var w *model.ContentWorld
	for i := range rows.worlds {
		if rows.worlds[i].CourseID == courseID && rows.worlds[i].Folder == folder {
			w = &rows.worlds[i]
		}
	}
	if w == nil {
		return ContentWorldView{}, domain.Invalid("only worlds added in the admin panel can be edited here")
	}
	old, err := worldView(*w)
	if err != nil {
		return ContentWorldView{}, err
	}
	w.Doc = worldDoc(old.ID, old.Order, in)
	for _, live := range []bool{false, true} {
		if _, err := s.load(rows.files(live), !live); err != nil {
			return ContentWorldView{}, problemsOf(err, path.Join("courses", courseID))
		}
	}
	if err := s.repo.SaveWorld(ctx, w); err != nil {
		return ContentWorldView{}, err
	}
	if live, ok := s.store.Get().Course(courseID); ok {
		for _, lw := range live.Worlds {
			if lw.Folder == folder {
				if err := s.changed(ctx); err != nil {
					return ContentWorldView{}, err
				}
			}
		}
	}
	return worldView(*w)
}

// DeleteWorld removes a world added in the panel that has no levels.
func (s *ContentService) DeleteWorld(ctx context.Context, courseID, folder string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.rows(ctx)
	if err != nil {
		return err
	}
	for _, l := range rows.levels {
		if l.CourseID == courseID && l.World == folder {
			return domain.Invalid("delete the world's levels first")
		}
	}
	found := false
	for _, w := range rows.worlds {
		found = found || (w.CourseID == courseID && w.Folder == folder)
	}
	if !found {
		return domain.ErrNotFound
	}
	return s.repo.DeleteWorld(ctx, courseID, folder)
}

// Courses lists the served courses (the panel picks one).
func (s *ContentService) Courses() []model.CourseSummary {
	out := []model.CourseSummary{}
	for _, c := range s.store.Get().Courses() {
		out = append(out, c.Summary)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}
