package domain

import (
	"strings"
	"testing"
	"time"
)

func TestDefaultControlsKeepTheAppAsItWas(t *testing.T) {
	c := DefaultControls(30)
	if c.Features["stories"] != ModeOff || c.Features["room"] != ModeOn {
		t.Fatalf("stories wait, the room stays: %v", c.Features)
	}
	if c.Billing.FreeLevels != 30 || c.Billing.GuestLevels != 1 || c.Billing.TrialDays != TrialDays || !c.Billing.Enabled {
		t.Fatalf("billing as before: %+v", c.Billing)
	}
	if c.Room.Items["crown"].Price != 40 || len(c.Games) != len(GameTypes) || len(c.PencilColors) != 6 {
		t.Fatalf("items, games and colours: %+v", c)
	}
	if err := c.Validate(210); err != nil {
		t.Fatalf("the defaults are valid: %v", err)
	}
}

func TestFillAddsSwitchesMissingFromAnOldSave(t *testing.T) {
	old := Controls{Features: map[string]string{"stories": ModeOn}}
	got := old.Fill(DefaultControls(30))
	if got.Features["stories"] != ModeOn || got.Features["stickers"] != ModeOn || got.Stories.Episodes["a"] != ModeOn {
		t.Fatalf("saved values kept, new ones filled: %v %v", got.Features, got.Stories)
	}
	if got.Room.Items["cap"].Price != 12 || !got.Games["pop"] {
		t.Fatal("items and games filled")
	}
}

func TestValidateRefusesWhatWouldBreakTheApp(t *testing.T) {
	cases := map[string]func(c *Controls){
		"cannot be":             func(c *Controls) { c.Features["certificate"] = ModePlus },
		"price":                 func(c *Controls) { c.Room.Items["cap"] = ItemControl{Price: 0} },
		"at least one Pencil":   func(c *Controls) { c.PencilColors = nil },
		"unknown Pencil":        func(c *Controls) { c.PencilColors = []string{"#000000"} },
		"free levels":           func(c *Controls) { c.Billing.FreeLevels = 500 },
		"only play free levels": func(c *Controls) { c.Billing.GuestLevels = 31 },
		"more levels":           func(c *Controls) { c.Billing.TrialLevels = 20 },
		"trial days":            func(c *Controls) { c.Billing.TrialDays = 0 },
		"one plan":              func(c *Controls) { c.Billing.Monthly, c.Billing.Yearly = false, false },
		"a date":                func(c *Controls) { c.Billing.FreeForAllUntil = "2026-13-40" },
		"0.1.0+7":               func(c *Controls) { c.App.MinVersion = "new" },
		"maintenance":           func(c *Controls) { c.App.Maintenance = Notice{On: true} },
		"message to parents":    func(c *Controls) { c.App.ParentMessage = Notice{On: true, Title: "Hi"} },
		"60 characters":         func(c *Controls) { c.Billing.Benefits = []string{strings.Repeat("x", 61)} },
	}
	for want, edit := range cases {
		c := DefaultControls(30)
		edit(&c)
		err := c.Validate(210)
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("%s: got %v", want, err)
		}
	}
}

func TestValidateTidiesUp(t *testing.T) {
	c := DefaultControls(30)
	c.Features["gone"] = ModeOn
	c.Room.Items["spaceship"] = ItemControl{Price: 5}
	c.PencilColors = []string{"#ffc83d", "#FFC83D"}
	c.Billing.Benefits = []string{"  One  ", "", "Two"}
	c.Billing.Yearly, c.Billing.BestValue = false, "yearly"
	if err := c.Validate(210); err != nil {
		t.Fatal(err)
	}
	if _, ok := c.Features["gone"]; ok {
		t.Error("unknown feature dropped")
	}
	if _, ok := c.Room.Items["spaceship"]; ok {
		t.Error("unknown item dropped")
	}
	if len(c.PencilColors) != 1 || c.PencilColors[0] != "#FFC83D" {
		t.Errorf("colours: %v", c.PencilColors)
	}
	if len(c.Billing.Benefits) != 2 || c.Billing.Benefits[0] != "One" {
		t.Errorf("benefits: %q", c.Billing.Benefits)
	}
	if c.Billing.BestValue != "" {
		t.Error("best value of a plan not offered is cleared")
	}
}

func TestLevelsNeedPlusAsTheBillingSays(t *testing.T) {
	now := time.Date(2026, 10, 21, 12, 0, 0, 0, time.UTC)
	b := DefaultControls(30).Billing
	if b.NeedsPlus(30, now) || !b.NeedsPlus(31, now) {
		t.Fatal("levels after the free ones need Plus")
	}
	b.TrialLevels = 60
	if b.TrialBlocks(60, now) || !b.TrialBlocks(61, now) || b.TrialBlocks(10, now) {
		t.Fatal("the trial opens up to level 60")
	}
	b.FreeForAllUntil = "2026-10-21"
	if b.NeedsPlus(100, now) || !b.FreeForAll(now) {
		t.Fatal("free for everyone until the end of the day")
	}
	if b.FreeForAll(time.Date(2026, 10, 22, 0, 0, 1, 0, time.UTC)) {
		t.Fatal("the promotion ends")
	}
	b.FreeForAllUntil, b.Enabled = "", false
	if b.NeedsPlus(200, now) || b.TrialBlocks(200, now) {
		t.Fatal("billing off: every level free")
	}
}

func TestResolve(t *testing.T) {
	on, off := true, false
	for _, c := range []struct {
		mode     string
		own      *bool
		plusFree bool
		want     string
	}{
		{ModeOn, nil, false, ModeOn},
		{ModeOff, nil, false, ModeOff},
		{ModeOff, &on, false, ModeOn},
		{ModeOn, &off, false, ModeOff},
		{ModeChosen, nil, false, ModeOff},
		{ModeChosen, &on, false, ModeOn},
		{ModePlus, nil, false, ModePlus},
		{ModePlus, nil, true, ModeOn},
	} {
		if got := Resolve(c.mode, c.own, c.plusFree); got != c.want {
			t.Errorf("Resolve(%s, %v, %v) = %s, want %s", c.mode, c.own, c.plusFree, got, c.want)
		}
	}
}

func TestItemPricesAndHiddenItems(t *testing.T) {
	c := DefaultControls(30)
	c.Room.Items["cap"] = ItemControl{Price: 3}
	c.Room.Items["crown"] = ItemControl{Hidden: true, Price: 40}
	if it, ok := c.Item("cap"); !ok || it.Price != 3 || !it.Wear {
		t.Fatalf("cap at its new price: %+v", it)
	}
	if _, ok := c.Item("crown"); ok {
		t.Fatal("hidden items cannot be had")
	}
	if _, ok := c.Item("spaceship"); ok {
		t.Fatal("unknown item")
	}
}

func TestOverrideKeys(t *testing.T) {
	for k, want := range map[string]bool{"stories": true, "story.a": true, "story.z": false, "music": false, "": false} {
		if ValidOverrideKey(k) != want {
			t.Errorf("%q: want %v", k, want)
		}
	}
}

func TestNoticeIDChangesWithTheText(t *testing.T) {
	a, b := Notice{Title: "Hi", Text: "One"}, Notice{Title: "Hi", Text: "Two"}
	if a.ID() == b.ID() || a.ID() != (Notice{Title: "Hi", Text: "One", On: true}).ID() {
		t.Fatal("the id follows the words only")
	}
}
