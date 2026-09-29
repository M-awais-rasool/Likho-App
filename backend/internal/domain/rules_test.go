package domain

import (
	"errors"
	"fmt"
	"testing"
)

func TestGain(t *testing.T) {
	two, three := 2, 3
	cases := []struct {
		old   *int
		stars int
		want  int
	}{
		{nil, 1, 3}, // first time: stars + 2
		{nil, 3, 5},
		{&two, 3, 1},   // better: the difference
		{&three, 1, 0}, // worse: nothing
		{&three, 3, 0},
	}
	for _, c := range cases {
		if got := Gain(c.old, c.stars); got != c.want {
			t.Errorf("Gain(%v, %d) = %d, want %d", c.old, c.stars, got, c.want)
		}
	}
}

func TestUnlocked(t *testing.T) {
	done := map[int]bool{1: true, 2: true}
	f := func(n int) bool { return done[n] }
	for level, want := range map[int]bool{1: true, 2: true, 3: true, 4: false, 36: false} {
		if got := Unlocked(level, f); got != want {
			t.Errorf("Unlocked(%d) = %v, want %v", level, got, want)
		}
	}
}

func TestTap(t *testing.T) {
	party, lamp := Items["party"], Items["lamp"]
	id := "party"
	cases := []struct {
		name    string
		item    Item
		owned   bool
		stars   int
		wearing *string
		placed  bool
		want    string
		ok      bool
	}{
		{"cannot afford", party, false, 7, nil, false, "", false},
		{"buy", party, false, 8, nil, false, Bought, true},
		{"wear", party, true, 0, nil, false, Worn, true},
		{"take off", party, true, 0, &id, false, TakenOff, true},
		{"place", lamp, true, 0, nil, false, Placed, true},
		{"remove", lamp, true, 0, nil, true, Removed, true},
	}
	for _, c := range cases {
		got, ok := Tap(c.item, c.owned, c.stars, c.wearing, c.placed)
		if got != c.want || ok != c.ok {
			t.Errorf("%s: got (%q, %v), want (%q, %v)", c.name, got, ok, c.want, c.ok)
		}
	}
}

func TestValidation(t *testing.T) {
	if !ValidColor("#ffc83d") || ValidColor("#000000") {
		t.Error("colours: only the six Pencil colours, any case")
	}
	if n, ok := CleanName("  Zara "); !ok || n != "Zara" {
		t.Errorf("CleanName trims: %q %v", n, ok)
	}
	if _, ok := CleanName("abcdefghijklmno"); ok {
		t.Error("15 letters is too long")
	}
	if _, ok := CleanName("زارا"); !ok {
		t.Error("names count letters, not bytes")
	}
	if ValidAge(4) || !ValidAge(8) || !ValidSessionMinutes(15) || ValidSessionMinutes(7) {
		t.Error("age 5..8, session 5/10/15")
	}
}

func TestStarsAndSeconds(t *testing.T) {
	if ValidStars(0) || !ValidStars(1) || !ValidStars(3) || ValidStars(4) {
		t.Error("stars 1..3")
	}
	if LevelSeconds(0) != DefaultLevelSeconds || LevelSeconds(95) != 95 || LevelSeconds(99999) != MaxLevelSeconds {
		t.Error("seconds: default when missing, capped")
	}
}

func TestErrorsMatchByCode(t *testing.T) {
	wrapped := fmt.Errorf("record: %w", ErrLevelLocked)
	if !errors.Is(wrapped, ErrLevelLocked) || errors.Is(wrapped, ErrTrialUsed) {
		t.Error("errors.Is matches the code through wrapping")
	}
	var e *Error
	if !errors.As(Invalid("stars must be 1 to 3"), &e) || e.Kind != KindInvalid || e.Code != "invalid_input" {
		t.Errorf("Invalid: %+v", e)
	}
}
