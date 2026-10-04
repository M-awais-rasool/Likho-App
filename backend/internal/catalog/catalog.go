// Package catalog loads Likho's learning content (backend/content), checks
// it and keeps every course ready to serve.
//
// Content is authored as many small JSON files (one per world and per
// level, see content/README.md) and delivered as one document per course,
// built once at start-up: compact JSON, a gzipped copy and an ETag, so
// serving a course costs no work and phones download it only when it
// changed.
package catalog

import (
	"encoding/json"
	"io/fs"
	"sort"
	"sync/atomic"

	"likho/backend/internal/model"
)

// SupportedSchema is the content format version this server (and the app)
// understands.
const SupportedSchema = 1

// Options changes what is served.
type Options struct {
	// IncludeDrafts serves courses marked "status": "draft" (development).
	// Drafts are always checked.
	IncludeDrafts bool
}

// Catalog is every course that is served, by id.
type Catalog struct {
	courses []*Course
	byID    map[string]*Course
}

// Course is one course, ready to serve.
type Course struct {
	Summary model.CourseSummary
	Draft   bool
	Stats   Stats

	ETag string // quoted, for the ETag header
	JSON []byte // the delivery document (GET /v1/courses/:id)
	Gzip []byte // JSON, gzipped

	// Dir is the course folder in the content ("courses/<id>"); Worlds are
	// its worlds in map order (for the admin panel).
	Dir    string
	Worlds []World

	levels map[int]Level
}

// Level is what the API (and the admin panel) needs to know about a map
// level.
type Level struct {
	Number               int
	ID                   string
	WorldID              string
	IsBoss               bool
	RequiresSubscription bool

	Name, Skill, Icon string
	Rounds            int
	File              string          // its file in the content, e.g. courses/x/worlds/01-a/levels/01-b.json
	Doc               json.RawMessage // the file as authored (without "$schema")
}

// World is a world of the course and the folder it lives in.
type World struct {
	ID, Name, Skill, Icon, ThemeID string
	Order                          int
	BossID, BossName               string
	Folder                         string // e.g. "06-story-space"
	Levels                         []int  // its map level numbers
}

// Stats counts what a course contains.
type Stats struct {
	Worlds, Levels, Rounds int
	Placement              bool
}

// Level looks up a map level by number (the placement warm-up is not one).
func (c *Course) Level(n int) (Level, bool) {
	l, ok := c.levels[n]
	return l, ok
}

// Levels returns the map levels in number order.
func (c *Course) Levels() []Level {
	out := make([]Level, 0, len(c.levels))
	for _, l := range c.levels {
		out = append(out, l)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Number < out[j].Number })
	return out
}

// LastLevel is the highest map level number (the end of the course).
func (c *Course) LastLevel() int { return c.Stats.Levels }

// Load reads every course under courses/ in [fsys], checks all of them and
// returns the ones to serve. The error lists every problem found, each with
// its file, so authors can fix them in one go.
func Load(fsys fs.FS, opt Options) (*Catalog, error) {
	all, err := loadAll(fsys)
	if err != nil {
		return nil, err
	}
	cat := &Catalog{byID: map[string]*Course{}}
	for _, c := range all {
		if c.Draft && !opt.IncludeDrafts {
			continue
		}
		cat.courses = append(cat.courses, c)
		cat.byID[c.Summary.ID] = c
	}
	sort.Slice(cat.courses, func(i, j int) bool { return cat.courses[i].Summary.ID < cat.courses[j].Summary.ID })
	return cat, nil
}

// Courses returns the served courses, by id.
func (c *Catalog) Courses() []*Course { return c.courses }

// Course returns a served course.
func (c *Catalog) Course(id string) (*Course, bool) {
	co, ok := c.byID[id]
	return co, ok
}

// Store holds the catalog being served. The admin panel can publish new
// content while the API runs: it builds a new catalog and swaps it in, so
// requests always see one whole, checked catalog.
type Store struct {
	p atomic.Pointer[Catalog]
}

func NewStore(c *Catalog) *Store {
	s := &Store{}
	s.p.Store(c)
	return s
}

// Get returns the catalog being served.
func (s *Store) Get() *Catalog { return s.p.Load() }

// Set serves [c] from now on.
func (s *Store) Set(c *Catalog) { s.p.Store(c) }
