package catalog

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
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
	if c.Stats.Worlds != 14 || c.Stats.Levels != 210 || !c.Stats.Placement || c.Stats.Rounds < 210*8 {
		t.Errorf("stats: %+v", c.Stats)
	}
	// worlds 1 and 2 (capitals A-Z) are free, Likho Plus from world 3
	if l, ok := c.Level(30); !ok || l.RequiresSubscription || l.WorldID != "world-2" || !l.IsBoss {
		t.Errorf("level 30: %+v", l)
	}
	if l, ok := c.Level(31); !ok || !l.RequiresSubscription || l.WorldID != "world-3" {
		t.Errorf("level 31: %+v", l)
	}
	// every world is 15 levels, its boss last
	for w := 1; w <= 14; w++ {
		if l, _ := c.Level(15 * w); !l.IsBoss || l.WorldID != fmt.Sprintf("world-%d", w) {
			t.Errorf("level %d is the boss of world %d", 15*w, w)
		}
	}
	// every level is 8 to 10 games long
	for n := 1; n <= 210; n++ {
		if l, _ := c.Level(n); l.Rounds < 8 || l.Rounds > 10 {
			t.Errorf("level %d has %d rounds", n, l.Rounds)
		}
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
	if doc.SchemaVersion != 1 || doc.CourseID != "english-handwriting" || len(doc.Worlds) != 14 || len(doc.Levels) != 211 || len(doc.Glyphs) == 0 {
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
		[]byte(`"intro":{"text":"A","word":"apple","say":"{A|ˈeɪ} is for apple!","audio":"voice/l1-intro.m4a"`), 1)
	f.Data = bytes.Replace(f.Data, []byte(`"prompt":{"text":"Trace A"}`), []byte(`"prompt":{"text":"Trace A","say":"Trace {A|ˈeɪ}.","audio":"https://cdn.likho.app/a.m4a"}`), 1)
	if _, err := Load(fs, Options{}); err != nil {
		t.Fatalf("say with pronunciations and assets or URLs are fine: %v", err)
	}
}

func TestMediaPathsAreTheFilesTheCourseUses(t *testing.T) {
	fs := course()
	f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
	f.Data = bytes.Replace(f.Data, []byte(`"intro":{"text":"A","word":"apple","picture":null}`),
		[]byte(`"intro":{"text":"A","word":"apple","audio":"voice/a.m4a","picture":{"key":"apple","label":"apple","url":null}}`), 1)
	cat, err := Load(fs, Options{})
	if err != nil {
		t.Fatal(err)
	}
	c, _ := cat.Course("demo")
	if got := strings.Join(c.MediaPaths(), " "); got != "pictures/apple.png voice/a.lip voice/a.m4a" {
		t.Errorf("media paths: %s", got)
	}
}

func TestHuntRoundsLoad(t *testing.T) {
	fs := course()
	f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
	f.Data = bytes.Replace(f.Data, []byte(`"type":"pick","prompt":{"text":"Find A"},"pick":{"options":[{"id":"o1","label":"A"},{"id":"o2","label":"B"}],"answer":{"kind":"label","value":"A"}}`),
		[]byte(`"type":"hunt","prompt":{"text":"Find every A"},"hunt":{"target":"A","grid":["A","B","A","C"]}`), 1)
	if _, err := Load(fs, Options{}); err != nil {
		t.Fatalf("a letter hunt is fine: %v", err)
	}
}

func TestNewGamesLoad(t *testing.T) {
	for _, round := range []string{
		`"type":"fix","prompt":{"text":"Fix it"},"fix":{"items":[{"text":"b","wrong":null,"at":null},{"text":"b","wrong":"mirror","at":null},{"text":"bed","wrong":"upside","at":0}]}`,
		`"type":"sort","prompt":{"text":"Feed it"},"sort":{"bins":[{"label":"b","picture":null,"bin":null}],"items":[{"label":"ball","picture":{"key":"ball","label":"ball","url":null},"bin":0},{"label":"sun","picture":null,"bin":null}]}`,
		`"type":"sort","prompt":{"text":"Sort"},"sort":{"bins":[{"label":"A"},{"label":"a"}],"items":[{"label":"A","bin":0},{"label":"a","bin":1}]}`,
		`"type":"match","prompt":{"text":"Pairs"},"match":{"pairs":[{"a":{"text":"A"},"b":{"text":"a"}},{"a":{"text":"cat"},"b":{"picture":{"key":"cat","label":"cat","url":null}}}]}`,
		`"type":"pop","prompt":{"text":"Pop b"},"pop":{"target":"b","others":["d","p"],"count":5}`,
		`"type":"truth","prompt":{"text":"True or silly?"},"truth":{"text":"The cat can fly.","picture":null,"answer":false}`,
		`"type":"write","prompt":{"text":"Look, then write"},"write":{"mode":"flash","guide":"A"}`,
		`"type":"sounds","prompt":{"text":"Tap each sound"},"sounds":{"word":"ship","parts":[{"text":"sh","say":"{/sh/|ʃːː}"},{"text":"i"},{"text":"p"}],"blend":{"text":"ship"},"choices":[{"label":"ship","picture":{"key":"ship","label":"ship","url":null}},{"label":"sun"}],"answer":0}`,
		`"type":"beats","prompt":{"text":"Clap the beats"},"beats":{"text":"apple","parts":["ap","ple"],"unit":"syllable","picture":null,"hint":{"text":"ap-ple","say":"Apple. Two beats!"}}`,
		`"type":"beats","prompt":{"text":"A beat a word"},"beats":{"text":"I see a cat.","parts":["I","see","a","cat"],"unit":"word"}`,
		`"type":"connect","prompt":{"text":"Join A to D"},"connect":{"labels":["A","B","C","D"],"points":[[50,0],[100,50],[50,100],[0,50]],"picture":{"key":"kite","label":"kite","url":null},"done":{"text":"A kite!"}}`,
	} {
		fs := course()
		f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
		f.Data = bytes.Replace(f.Data, []byte(`"type":"pick","prompt":{"text":"Find A"},"pick":{"options":[{"id":"o1","label":"A"},{"id":"o2","label":"B"}],"answer":{"kind":"label","value":"A"}}`), []byte(round), 1)
		if _, err := Load(fs, Options{}); err != nil {
			t.Errorf("%s: %v", round, err)
		}
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
		{"recording that is neither a media file nor a URL", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"prompt":{"text":"Trace A"}`), []byte(`"prompt":{"text":"Trace A","audio":"../a.m4a"}`), 1)
		}, []string{"01-a.json rounds[0] prompt", `audio "../a.m4a" must be a file in the media folder`}},
		{"pronunciation without its IPA", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"intro":{"text":"A","word":"apple"`), []byte(`"intro":{"text":"A","word":"apple","say":"Small {a}!"`), 1)
		}, []string{"01-a.json intro", `say "Small {a}!": a pronunciation is written {shown|IPA}`}},
		{"hunt without the letter to find", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"hunt","prompt":{"text":"Find every A"},"hunt":{"target":"A","grid":["B","C","D","E"]}`), 1)
		}, []string{"01-a.json rounds[0]", "hunt.grid needs the target and at least one other cell"}},
		{"a fix with nothing to fix", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"fix","prompt":{"text":"Fix"},"fix":{"items":[{"text":"b"},{"text":"b"},{"text":"b","wrong":"sideways","at":3}]}`), 1)
		}, []string{`fix.items[2].wrong "sideways" is not one of`, `fix.items[2].at 3 is not a letter of "b"`}},
		{"baskets with an item that has no basket", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"sort","prompt":{"text":"Sort"},"sort":{"bins":[{"label":"A"},{"label":"a"}],"items":[{"label":"A","bin":0},{"label":"x"}]}`), 1)
		}, []string{"sort.items[1] needs a bin", "every bin needs at least one item"}},
		{"pop with the target among the others", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"pop","prompt":{"text":"Pop"},"pop":{"target":"b","others":["b"],"count":3}`), 1)
		}, []string{"pop.others must be labels other than the target"}},
		{"truth without an answer", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"truth","prompt":{"text":"Hm"},"truth":{"text":"The sun is cold."}`), 1)
		}, []string{"truth needs a text and an answer"}},
		{"saying aloud is gone: the app does not listen", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"speak","prompt":{"text":"Say A"},"speak":{"expected":"A"}`), 1)
		}, []string{"01-a.json", `unknown field "speak"`}},
		{"sound buttons that do not spell the word", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"sounds","prompt":{"text":"Tap"},"sounds":{"word":"cat","parts":[{"text":"c"},{"text":"u"},{"text":"t"}],"choices":[{"label":"cat"}],"answer":3}`), 1)
		}, []string{`sounds.parts spell "cut", not the word "cat"`, "sounds.blend: text is required", "sounds.choices needs 2 to 4 pictures", "sounds.answer must be the index"}},
		{"beats without beats", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"beats","prompt":{"text":"Clap"},"beats":{"text":"apple","parts":[],"unit":"clap"}`), 1)
		}, []string{"beats.parts needs 1 to 8 beats", `beats.unit "clap" is not one of syllable, word`}},
		{"dots without a point each", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"type":"write","prompt":{"text":"Trace A"},"write":{"mode":"trace","guide":"A"}`),
				[]byte(`"type":"connect","prompt":{"text":"Join"},"connect":{"labels":["A","B","B","D"],"points":[[50,0],[100,50],[50,140]]}`), 1)
		}, []string{"connect needs one point per label", `connect.labels[2] "B" must be a label not used before`, "connect.points[2] must be [x, y] from 0 to 100"}},
		{"writing pads are gone: there is only the paper", func(fs fstest.MapFS) {
			f := fs["courses/demo/worlds/01-one/levels/01-a.json"]
			f.Data = bytes.Replace(f.Data, []byte(`"mode":"trace","guide":"A"`), []byte(`"mode":"trace","guide":"A","pad":"sand"`), 1)
		}, []string{"01-a.json", `unknown field "pad"`}},
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
