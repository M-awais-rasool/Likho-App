package domain

import (
	"errors"
	"testing"
)

// english is the real course: KG levels 1-12, Class 1 13-24, Class 2 25-30,
// Class 3 31-36.
func english() Ladder {
	l := make(Ladder, 36)
	for i := range l {
		switch n := i + 1; {
		case n <= 12:
			l[i] = 0
		case n <= 24:
			l[i] = 1
		case n <= 30:
			l[i] = 2
		default:
			l[i] = 3
		}
	}
	return l
}

func doneUpTo(last int, also ...int) func(int) bool {
	return func(n int) bool {
		for _, a := range also {
			if n == a {
				return true
			}
		}
		return n >= 1 && n <= last
	}
}

func TestUnlockedByClass(t *testing.T) {
	l := english()
	cases := []struct {
		name        string
		grade, open string
		done        func(int) bool
		open1       []int // unlocked
		locked      []int
	}{
		{"KG from the start: in order", "kg", "kg", doneUpTo(0), []int{1}, []int{0, 2, 12, 13, 37}},
		{"KG after 2 levels", "kg", "kg", doneUpTo(2), []int{1, 2, 3}, []int{4, 12}},
		{"KG finished: Class 1 waits for a parent", "kg", "kg", doneUpTo(12), []int{12}, []int{13, 14}},
		{"KG with Class 1 opened", "kg", "class-1", doneUpTo(12), []int{13}, []int{14, 25}},
		{"Class 1 opened before KG is done: still in order", "kg", "class-1", doneUpTo(5), []int{6}, []int{7, 13}},
		{"Class 1: KG is revision, 13 is the start", "class-1", "class-1", doneUpTo(0), []int{1, 7, 12, 13}, []int{14, 25}},
		{"Class 1 played on", "class-1", "class-1", doneUpTo(0, 13, 14), []int{13, 14, 15, 5}, []int{16, 24}},
		{"Class 3: everything below is revision", "class-3", "class-3", doneUpTo(0), []int{1, 24, 30, 31}, []int{32}},
		{"moved down a class: higher levels lock, stars kept", "kg", "kg", doneUpTo(27), []int{1, 12}, []int{13, 20, 27}},
		{"unknown class: the course's first class", "", "", doneUpTo(0), []int{1}, []int{2, 13}},
	}
	for _, c := range cases {
		for _, n := range c.open1 {
			if !l.Unlocked(n, c.grade, c.open, c.done) {
				t.Errorf("%s: level %d should be open", c.name, n)
			}
		}
		for _, n := range c.locked {
			if l.Unlocked(n, c.grade, c.open, c.done) {
				t.Errorf("%s: level %d should be locked", c.name, n)
			}
		}
	}
}

func TestACourseAboveOrBelowTheChild(t *testing.T) {
	// a course for Class 1 and 2 only
	l := Ladder{1, 1, 1, 2, 2}
	none := doneUpTo(0)
	if !l.Unlocked(1, "kg", "kg", none) || l.Unlocked(2, "kg", "kg", none) || l.Unlocked(4, "kg", "kg", doneUpTo(3)) {
		t.Error("a KG child starts at the course's first class, in order, and not beyond it")
	}
	if !l.Unlocked(5, "class-3", "class-3", none) {
		t.Error("a course below the child's class is all revision")
	}
	if l.Start(2) != 4 || l.Start(3) != 6 || english().Start(1) != 13 {
		t.Error("Start: the first level of a class or above")
	}
}

func TestChangeGrade(t *testing.T) {
	s := func(v string) *string { return &v }
	cases := []struct {
		name                string
		grade, open         string
		toGrade, toOpen     *string
		wantGrade, wantOpen string
		invalid             bool
	}{
		{"confirming keeps an opened class", "kg", "class-1", s("kg"), nil, "kg", "class-1", false},
		{"a new class locks higher ones again", "kg", "class-1", s("class-1"), nil, "class-1", "class-1", false},
		{"moving down locks too", "class-2", "class-3", s("kg"), nil, "kg", "kg", false},
		{"a parent opens the next class", "kg", "kg", nil, s("class-1"), "kg", "class-1", false},
		{"new class and opened together", "kg", "kg", s("class-1"), s("class-2"), "class-1", "class-2", false},
		{"closing again down to the class", "kg", "class-2", nil, s("kg"), "kg", "kg", false},
		{"not below the class", "class-1", "class-1", nil, s("kg"), "", "", true},
		{"unknown class", "kg", "kg", s("class-9"), nil, "", "", true},
		{"unknown open class", "kg", "kg", nil, s("Class 1"), "", "", true},
	}
	for _, c := range cases {
		g, o, err := ChangeGrade(c.grade, c.open, c.toGrade, c.toOpen)
		var e *Error
		if c.invalid {
			if !errors.As(err, &e) || e.Kind != KindInvalid {
				t.Errorf("%s: want an invalid_input error, got %v", c.name, err)
			}
			continue
		}
		if err != nil || g != c.wantGrade || o != c.wantOpen {
			t.Errorf("%s: got (%q, %q, %v), want (%q, %q)", c.name, g, o, err, c.wantGrade, c.wantOpen)
		}
	}
}

func TestGrades(t *testing.T) {
	for age, want := range map[int]string{5: "kg", 6: "class-1", 7: "class-2", 8: "class-3", 0: "kg", 12: "class-3"} {
		if got := GradeForAge(age); got != want {
			t.Errorf("GradeForAge(%d) = %s, want %s", age, got, want)
		}
	}
	if GradeRank("kg") != 0 || GradeRank("class-3") != 3 || GradeRank("Class 1") != -1 || ValidGrade("") {
		t.Error("ranks: KG first, unknown ids -1")
	}
	if GradeList() != "kg, class-1, class-2 or class-3" {
		t.Errorf("GradeList: %s", GradeList())
	}
}
