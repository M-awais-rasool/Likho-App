package catalog

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Layout of a course folder:
//
//	courses/<course-id>/
//	    course.json               manifest (id = folder name)
//	    glyphs.json               letter guides
//	    placement.json            warm-up level, number 0 (optional)
//	    worlds/<NN-name>/
//	        world.json            NN = its order
//	        levels/<NN-name>.json NN = its number
const coursesDir = "courses"

var (
	slugRe     = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
	roundTypes = map[string]bool{
		"pick": true, "write": true, "order": true, "hunt": true, "fix": true, "sort": true, "match": true, "pop": true, "truth": true,
		"sounds": true, "beats": true, "connect": true,
	}
	slots      = map[string]bool{"wagon": true, "plank": true, "stripe": true, "panel": true}
	stages     = map[string]bool{"house": true, "count": true, "stars": true}
	writeModes = map[string]bool{"trace": true, "dots": true, "free": true, "flash": true, "missing": true, "spell": true}
	fixWrongs  = map[string]bool{"mirror": true, "upside": true}
	colors     = map[string]bool{"red": true, "blue": true, "yellow": true, "green": true, "purple": true}
)

// problems collects every content error, each prefixed with its file.
type problems []error

func (p *problems) add(file, format string, args ...any) {
	*p = append(*p, fmt.Errorf("%s: %s", file, fmt.Sprintf(format, args...)))
}

func loadAll(fsys fs.FS) ([]*Course, error) {
	entries, err := fs.ReadDir(fsys, coursesDir)
	if err != nil {
		return nil, fmt.Errorf("content: %w", err)
	}
	var courses []*Course
	var errs problems
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		c, p := loadCourse(fsys, path.Join(coursesDir, e.Name()), e.Name())
		errs = append(errs, p...)
		if c != nil {
			courses = append(courses, c)
		}
	}
	if len(errs) > 0 {
		return nil, fmt.Errorf("content has %d problem(s):\n%w", len(errs), errors.Join(errs...))
	}
	if len(courses) == 0 {
		return nil, errors.New("content: no courses in courses/")
	}
	return courses, nil
}

// parsed is one JSON file: its checked fields ([doc]) and everything in it
// ([raw]), which is what the app receives.
type parsed[T any] struct {
	file string
	doc  T
	raw  map[string]json.RawMessage
	data []byte // the file as authored
}

func readJSON[T any](fsys fs.FS, file string, p *problems) *parsed[T] {
	data, err := fs.ReadFile(fsys, file)
	if err != nil {
		p.add(file, "%v", err)
		return nil
	}
	out := &parsed[T]{file: file, data: data}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields() // a typo in a field name is an error, not a silent default
	if err := dec.Decode(&out.doc); err != nil {
		p.add(file, "%v", err)
		return nil
	}
	if dec.More() {
		p.add(file, "more than one JSON value")
		return nil
	}
	if err := json.Unmarshal(data, &out.raw); err != nil {
		p.add(file, "%v", err)
		return nil
	}
	delete(out.raw, "$schema") // for editors only
	return out
}

func loadCourse(fsys fs.FS, dir, name string) (*Course, problems) {
	var p problems
	m := readJSON[manifestDoc](fsys, path.Join(dir, "course.json"), &p)
	g := readJSON[glyphsDoc](fsys, path.Join(dir, "glyphs.json"), &p)
	if m == nil || g == nil {
		return nil, p
	}
	m.doc.check(m.file, name, &p)
	g.doc.check(g.file, &p)

	var placement *parsed[levelDoc]
	if _, err := fs.Stat(fsys, path.Join(dir, "placement.json")); err == nil {
		placement = readJSON[levelDoc](fsys, path.Join(dir, "placement.json"), &p)
	}

	worlds, levels := loadWorlds(fsys, path.Join(dir, "worlds"), &p)
	checkNumbering(dir, worlds, levels, &p)

	c := &checker{glyphs: g.doc.Glyphs, levelIDs: map[string]string{}, roundIDs: map[string]string{}, p: &p}
	if placement != nil {
		if n := placement.doc.Number; n == nil || *n != 0 {
			p.add(placement.file, "the placement level must have number 0")
		}
		c.level(placement)
	}
	for _, l := range levels {
		c.level(l.parsed)
	}
	if len(p) > 0 {
		return nil, p
	}

	course, err := build(m, g.doc.Glyphs, placement, worlds, levels)
	if err != nil {
		p.add(dir, "%v", err)
		return nil, p
	}
	course.Dir = dir
	return course, nil
}

// -------------------------------------------------------------- worlds

type worldFile struct {
	*parsed[worldDoc]
	folder string
}

type levelFile struct {
	*parsed[levelDoc]
	world *worldFile
}

func loadWorlds(fsys fs.FS, dir string, p *problems) ([]*worldFile, []*levelFile) {
	entries, err := fs.ReadDir(fsys, dir)
	if err != nil {
		p.add(dir, "a course needs a worlds/ folder: %v", err)
		return nil, nil
	}
	var worlds []*worldFile
	var levels []*levelFile
	for _, e := range entries {
		if !e.IsDir() {
			p.add(path.Join(dir, e.Name()), "only world folders belong in worlds/")
			continue
		}
		wdir := path.Join(dir, e.Name())
		w := readJSON[worldDoc](fsys, path.Join(wdir, "world.json"), p)
		if w == nil {
			continue
		}
		wf := &worldFile{parsed: w, folder: e.Name()}
		w.doc.check(w.file, e.Name(), p)
		worlds = append(worlds, wf)

		files, err := fs.ReadDir(fsys, path.Join(wdir, "levels"))
		if err != nil || len(files) == 0 {
			p.add(wdir, "a world needs at least one level in levels/")
			continue
		}
		for _, f := range files {
			file := path.Join(wdir, "levels", f.Name())
			if f.IsDir() || path.Ext(f.Name()) != ".json" {
				p.add(file, "only level .json files belong in levels/")
				continue
			}
			l := readJSON[levelDoc](fsys, file, p)
			if l == nil {
				continue
			}
			if n := l.doc.Number; n != nil && !strings.HasPrefix(f.Name(), fmt.Sprintf("%02d-", *n)) {
				p.add(file, "file name must start with the level number (%02d-…)", *n)
			}
			levels = append(levels, &levelFile{parsed: l, world: wf})
		}
	}
	return worlds, levels
}

// checkNumbering: world orders 1..n, map levels 1..n with no gaps, and the
// map goes up world by world (a world's levels come after the previous
// world's).
func checkNumbering(dir string, worlds []*worldFile, levels []*levelFile, p *problems) {
	sort.Slice(worlds, func(i, j int) bool { return worlds[i].doc.Order < worlds[j].doc.Order })
	ids := map[string]string{}
	for i, w := range worlds {
		if w.doc.Order != i+1 {
			p.add(w.file, "world order %d: orders must be 1, 2, 3… without gaps or repeats", w.doc.Order)
		}
		if prev, dup := ids[w.doc.ID]; dup {
			p.add(w.file, "world id %q is also used by %s", w.doc.ID, prev)
		}
		ids[w.doc.ID] = w.file
	}
	if len(worlds) == 0 {
		p.add(dir, "a course needs at least one world")
	}

	numbered := make([]*levelFile, 0, len(levels))
	for _, l := range levels {
		if l.doc.Number != nil {
			numbered = append(numbered, l)
		}
	}
	sort.Slice(numbered, func(i, j int) bool { return *numbered[i].doc.Number < *numbered[j].doc.Number })
	for i, l := range numbered {
		if n := *l.doc.Number; n != i+1 {
			p.add(l.file, "level number %d: map levels must be numbered 1, 2, 3… without gaps or repeats", n)
			break
		}
		if i > 0 && l.world.doc.Order < numbered[i-1].world.doc.Order {
			p.add(l.file, "level %d is in world %d but level %d is in world %d: numbers must go up world by world",
				*l.doc.Number, l.world.doc.Order, *numbered[i-1].doc.Number, numbered[i-1].world.doc.Order)
		}
	}
	for _, l := range levels {
		if l.doc.Number != nil && *l.doc.Number == 0 {
			p.add(l.file, "number 0 is the placement level (placement.json)")
		}
	}
}

// -------------------------------------------------------------- build

// build turns the checked files into the document the app receives: the
// same shape as before content was split into files.
func build(m *parsed[manifestDoc], glyphs map[string][]string, placement *parsed[levelDoc], worlds []*worldFile, levels []*levelFile) (*Course, error) {
	sort.Slice(levels, func(i, j int) bool { return *levels[i].doc.Number < *levels[j].doc.Number })

	doc := struct {
		SchemaVersion int                          `json:"schemaVersion"`
		CourseID      string                       `json:"courseId"`
		Title         string                       `json:"title"`
		UpdatedAt     string                       `json:"updatedAt"`
		Worlds        []map[string]json.RawMessage `json:"worlds"`
		Levels        []map[string]json.RawMessage `json:"levels"`
		Glyphs        map[string][]string          `json:"glyphs"`
	}{
		SchemaVersion: m.doc.SchemaVersion,
		CourseID:      m.doc.ID,
		Title:         m.doc.Title,
		UpdatedAt:     m.doc.UpdatedAt,
		Glyphs:        glyphs,
	}
	for _, w := range worlds {
		doc.Worlds = append(doc.Worlds, w.raw)
	}
	stats := Stats{Worlds: len(worlds), Levels: len(levels), Placement: placement != nil}
	index := make(map[int]Level, len(levels))
	if placement != nil {
		doc.Levels = append(doc.Levels, withWorld(placement.raw, nil))
		stats.Rounds += len(placement.doc.Rounds)
	}
	byWorld := map[string][]int{}
	for _, l := range levels {
		doc.Levels = append(doc.Levels, withWorld(l.raw, &l.world.doc.ID))
		stats.Rounds += len(l.doc.Rounds)
		index[*l.doc.Number] = Level{
			Number: *l.doc.Number, ID: l.doc.ID, WorldID: l.world.doc.ID,
			IsBoss: *l.doc.IsBoss, RequiresSubscription: *l.doc.RequiresSubscription,
			Name: l.doc.Name, Skill: l.doc.Skill, Icon: l.doc.Icon, Rounds: len(l.doc.Rounds),
			File: l.file, Doc: l.data,
		}
		byWorld[l.world.doc.ID] = append(byWorld[l.world.doc.ID], *l.doc.Number)
	}
	infos := make([]World, 0, len(worlds))
	for _, w := range worlds {
		d := w.doc
		infos = append(infos, World{
			ID: d.ID, Name: d.Name, Skill: d.Skill, Icon: d.Icon, ThemeID: d.ThemeID, Order: d.Order,
			BossID: d.Boss.ID, BossName: d.Boss.Name, Folder: w.folder, Levels: byWorld[d.ID],
		})
	}

	body, err := json.Marshal(doc)
	if err != nil {
		return nil, err
	}
	c := &Course{Draft: m.doc.Status == "draft", Stats: stats, levels: index, Worlds: infos}
	c.setBody(body)
	c.Summary.ID = m.doc.ID
	c.Summary.Title = m.doc.Title
	c.Summary.Description = m.doc.Description
	c.Summary.Locale = m.doc.Locale
	c.Summary.Ages = m.doc.Ages
	c.Summary.Worlds = stats.Worlds
	c.Summary.Levels = stats.Levels
	c.Summary.UpdatedAt = m.doc.UpdatedAt
	return c, nil
}

// withWorld adds what the file's place in the folders says: its world, and
// whether it is the placement level.
func withWorld(raw map[string]json.RawMessage, worldID *string) map[string]json.RawMessage {
	out := make(map[string]json.RawMessage, len(raw)+2)
	for k, v := range raw {
		out[k] = v
	}
	out["worldId"] = json.RawMessage("null")
	if worldID != nil {
		out["worldId"], _ = json.Marshal(*worldID)
	}
	out["placement"] = json.RawMessage(fmt.Sprint(worldID == nil))
	return out
}

func validTime(s string) bool {
	_, err := time.Parse(time.RFC3339, s)
	return err == nil
}
