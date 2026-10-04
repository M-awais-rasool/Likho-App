package catalog

import (
	"bytes"
	"testing"
)

func TestOverlayAddsAndReplacesFiles(t *testing.T) {
	base := course()
	one := base["courses/demo/worlds/01-one/levels/01-a.json"].Data
	edited := bytes.Replace(one, []byte(`"name":"L"`), []byte(`"name":"Edited"`), 1)
	if bytes.Equal(one, edited) {
		t.Fatal("test level has no name to edit")
	}
	// a new level after the last one, in the last world
	three := base["courses/demo/worlds/02-two/levels/03-c.json"].Data
	four := bytes.ReplaceAll(bytes.Replace(three, []byte(`"number":3`), []byte(`"number":4`), 1), []byte("l3"), []byte("l4"))

	cat, err := Load(Overlay(base, map[string][]byte{
		"courses/demo/worlds/01-one/levels/01-a.json": edited,
		"courses/demo/worlds/02-two/levels/04-d.json": four,
	}), Options{})
	if err != nil {
		t.Fatal(err)
	}
	c, _ := cat.Course("demo")
	if c.LastLevel() != 4 || len(c.Levels()) != 4 {
		t.Fatalf("levels: %d", c.LastLevel())
	}
	if l, _ := c.Level(1); l.Name != "Edited" {
		t.Errorf("the overlay replaces a file: %q", l.Name)
	}
	if w := c.Worlds[1]; w.Folder != "02-two" || len(w.Levels) != 2 {
		t.Errorf("world 2 has levels 3 and 4: %+v", w)
	}
	// the base is untouched
	plain, _ := Load(base, Options{})
	if p, _ := plain.Course("demo"); p.LastLevel() != 3 {
		t.Error("base changed")
	}
}

func TestStoreSwapsTheCatalog(t *testing.T) {
	a, _ := Load(course(), Options{})
	s := NewStore(a)
	b, _ := Load(course(), Options{IncludeDrafts: true})
	s.Set(b)
	if s.Get() != b {
		t.Error("Set serves the new catalog")
	}
}
