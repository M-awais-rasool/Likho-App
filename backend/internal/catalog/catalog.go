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
	"io/fs"
	"sort"

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

	levels map[int]Level
}

// Level is what the API needs to know about a map level.
type Level struct {
	Number               int
	ID                   string
	WorldID              string
	IsBoss               bool
	RequiresSubscription bool
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
