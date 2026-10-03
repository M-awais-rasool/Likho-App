package catalog

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"testing/fstest"

	"likho/backend/content"
)

func TestLoadsTheRealContent(t *testing.T) {
	cat, err := Load(content.FS, Options{})
	if err != nil {
		t.Fatal(err)
	}
	c, ok := cat.Course("english-handwriting")
	if !ok || len(cat.Courses()) != 1 {
		t.Fatalf("courses: %v", cat.Courses())
	}
	if c.Stats != (Stats{Worlds: 6, Levels: 36, Rounds: 182, Placement: true}) {
		t.Errorf("stats: %+v", c.Stats)
	}
	if l, ok := c.Level(13); !ok || !l.RequiresSubscription || l.WorldID != "world-3" {
		t.Errorf("level 13: %+v", l)
	}
	if l, _ := c.Level(6); !l.IsBoss {
		t.Error("level 6 is a boss")
	}
	if _, ok := c.Level(0); ok {
		t.Error("the placement warm-up is not a map level")
	}

	// the delivery document: the shape the app reads
	var doc struct {
		SchemaVersion int              `json:"schemaVersion"`
		CourseID      string           `json:"courseId"`
		Worlds        []map[string]any `json:"worlds"`
		Levels        []map[string]any `json:"levels"`
		Glyphs        map[string][]string
	}
	if err := json.Unmarshal(c.JSON, &doc); err != nil {
		t.Fatal(err)
	}
	if doc.SchemaVersion != 1 || doc.CourseID != "english-handwriting" || len(doc.Worlds) != 6 || len(doc.Levels) != 37 || len(doc.Glyphs) == 0 {
		t.Fatalf("document: v%d %s %d worlds %d levels", doc.SchemaVersion, doc.CourseID, len(doc.Worlds), len(doc.Levels))
	}
	first, second := doc.Levels[0], doc.Levels[1]
	if first["placement"] != true || first["worldId"] != nil || second["worldId"] != "world-1" || second["placement"] != false {
		t.Errorf("worldId / placement come from the folders: %v %v", first["worldId"], second["worldId"])
	}
	if _, ok := second["$schema"]; ok {
		t.Error("$schema is for editors, not the app")
	}

	// gzip copy and a stable ETag
	zr, err := gzip.NewReader(bytes.NewReader(c.Gzip))
	if err != nil {
		t.Fatal(err)
	}
	unzipped, _ := io.ReadAll(zr)
	if !bytes.Equal(unzipped, c.JSON) {
		t.Error("gzip copy differs")
	}
	again, _ := Load(content.FS, Options{})
	if c2, _ := again.Course("english-handwriting"); c2.ETag != c.ETag || c.Summary.Version == "" {
		t.Error("the same content always gets the same ETag")
	}
}

// course builds a small valid course; edit files to break it.
func course() fstest.MapFS {
	level := func(n int, id string) string {
		return `{"id":"` + id + `","number":` + itoa(n) + `,"name":"L","skill":"s","icon":"edit","isBoss":false,"requiresSubscription":false,
			"intro":{"text":"A","word":"apple","picture":null},"presentation":{"shape":null},
			"rounds":[{"id":"` + id + `-r1","type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}},
			          {"id":"` + id + `-r2","type":"pick","prompt":{"text":"Find A"},"pick":{"options":[{"id":"o1","label":"A"},{"id":"o2","label":"B"}],"answer":{"kind":"label","value":"A"}}}]}`
	}
	return fstest.MapFS{
		"courses/demo/course.json":                    {Data: []byte(`{"$schema":"x","id":"demo","title":"Demo","locale":"en","status":"published","schemaVersion":1,"updatedAt":"2026-01-01T00:00:00Z"}`)},
		"courses/demo/glyphs.json":                    {Data: []byte(`{"glyphs":{"A":["M0 0 L1 1"]}}`)},
		"courses/demo/worlds/01-one/world.json":       {Data: []byte(`{"id":"w1","order":1,"name":"One","skill":"s","icon":"grass","themeId":"t","boss":{"id":"b","name":"B"}}`)},
		"courses/demo/worlds/01-one/levels/01-a.json": {Data: []byte(level(1, "l1"))},
		"courses/demo/worlds/01-one/levels/02-b.json": {Data: []byte(level(2, "l2"))},
		"courses/demo/worlds/02-two/world.json":       {Data: []byte(`{"id":"w2","order":2,"name":"Two","skill":"s","icon":"grass","themeId":"t","boss":{"id":"b","name":"B"}}`)},
		"courses/demo/worlds/02-two/levels/03-c.json": {Data: []byte(level(3, "l3"))},
	}
}

func itoa(n int) string { b, _ := json.Marshal(n); return string(b) }

func TestSpokenWordsAndRecordings(t *testing.T) {
	fs := course()
	f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
	f.Data = bytes.Replace(f.Data, []byte(`"intro":{"text":"A","word":"apple"`),
		[]byte(`"intro":{"text":"A","word":"apple","say":"{A|ˈeɪ} is for apple!","audio":"assets/voice/l1-intro.m4a"`), 1)
	f.Data = bytes.Replace(f.Data, []byte(`"prompt":{"text":"Trace A"}`), []byte(`"prompt":{"text":"Trace A","say":"Trace {A|ˈeɪ}.","audio":"https://cdn.likho.app/a.m4a"}`), 1)
	if _, err := Load(fs, Options{}); err != nil {
		t.Fatalf("say with pronunciations and assets or URLs are fine: %v", err)
	}
}

func TestASmallCourseLoads(t *testing.T) {
	cat, err := Load(course(), Options{})
	if err != nil {
		t.Fatal(err)
	}
	c, _ := cat.Course("demo")
	if c.Stats != (Stats{Worlds: 2, Levels: 3, Rounds: 6}) {
		t.Errorf("stats: %+v", c.Stats)
	}
}

func TestContentProblemsAreReportedWithTheirFile(t *testing.T) {
	cases := []struct {
		name string
		edit func(fstest.MapFS)
		want []string
	}{
		{"typo in a field", func(fs fstest.MapFS) {
			fs["courses/demo/worlds/01-one/levels/01-a.json"].Data = bytes.Replace(fs["courses/demo/worlds/01-one/levels/01-a.json"].Data, []byte(`"isBoss"`), []byte(`"isBos"`), 1)
		}, []string{"01-a.json", `unknown field "isBos"`}},
		{"gap in level numbers", func(fs fstest.MapFS) {
			delete(fs, "courses/demo/worlds/01-one/levels/02-b.json")
		}, []string{"03-c.json", "without gaps"}},
		{"duplicate round id", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/02-two/levels/03-c.json"]
			f.Data = bytes.ReplaceAll(f.Data, []byte(`"l3-r1"`), []byte(`"l1-r1"`))
		}, []string{"03-c.json rounds[0]", `round id "l1-r1" is also used`}},
		{"guide missing from glyphs", func(fs fstest.MapFS) {
			fs["courses/demo/glyphs.json"].Data = []byte(`{"glyphs":{"B":["M0 0"]}}`)
		}, []string{`write.guide "A" is not in glyphs.json`}},
		{"unknown round type", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write"`), []byte(`"type":"draw"`), 1)
		}, []string{`type "draw" is not one of`}},
		{"answer not an option", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"value":"A"`), []byte(`"value":"Z"`), 1)
		}, []string{"answer.value must be the label of one of the options"}},
		{"course id is not the folder", func(fs fstest.MapFS) {
			fs["courses/demo/course.json"].Data = bytes.Replace(fs["courses/demo/course.json"].Data, []byte(`"id":"demo"`), []byte(`"id":"other"`), 1)
		}, []string{"course.json", `must match the folder name "demo"`}},
		{"file name does not match the number", func(fs fstest.MapFS) {
			fs["courses/demo/worlds/02-two/levels/9-c.json"] = fs["courses/demo/worlds/02-two/levels/03-c.json"]
			delete(fs, "courses/demo/worlds/02-two/levels/03-c.json")
		}, []string{"9-c.json", "must start with the level number (03-"}},
		{"recording that is neither an app asset nor a URL", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"prompt":{"text":"Trace A"}`), []byte(`"prompt":{"text":"Trace A","audio":"voice/a.m4a"}`), 1)
		}, []string{"01-a.json rounds[0] prompt", `audio "voice/a.m4a" must be an app asset`}},
		{"pronunciation without its IPA", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"intro":{"text":"A","word":"apple"`), []byte(`"intro":{"text":"A","word":"apple","say":"Small {a}!"`), 1)
		}, []string{"01-a.json intro", `say "Small {a}!": a pronunciation is written {shown|IPA}`}},
		{"levels go backwards across worlds", func(fs fstest.MapFS) {
			fs["courses/demo/worlds/01-one/levels/03-c.json"] = fs["courses/demo/worlds/02-two/levels/03-c.json"]
			fs["courses/demo/worlds/02-two/levels/02-b.json"] = fs["courses/demo/worlds/01-one/levels/02-b.json"]
			delete(fs, "courses/demo/worlds/02-two/levels/03-c.json")
			delete(fs, "courses/demo/worlds/01-one/levels/02-b.json")
		}, []string{"numbers must go up world by world"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			fs := course()
			tc.edit(fs)
			_, err := Load(fs, Options{})
			if err == nil {
				t.Fatal("expected a content error")
			}
			for _, w := range tc.want {
				if !strings.Contains(err.Error(), w) {
					t.Errorf("error should mention %q:\n%v", w, err)
				}
			}
		})
	}
}

func TestDraftsAreCheckedButOnlyServedWhenAsked(t *testing.T) {
	fs := course()
	fs["courses/demo/course.json"].Data = bytes.Replace(fs["courses/demo/course.json"].Data, []byte(`"published"`), []byte(`"draft"`), 1)
	cat, err := Load(fs, Options{})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := cat.Course("demo"); ok {
		t.Error("drafts are not served by default")
	}
	cat, _ = Load(fs, Options{IncludeDrafts: true})
	if c, ok := cat.Course("demo"); !ok || !c.Draft {
		t.Error("drafts are served when asked (development)")
	}
}
