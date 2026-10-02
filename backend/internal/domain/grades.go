package domain

import "strings"

// Classes. Every child is in a school class (a parent picks it when adding
// the child) and every world of a course is for one class. On the map the
// child plays their own class in order; lower classes stay open for
// revision; higher classes stay locked until a parent opens them.

// Grades are the school classes, lowest first.
var Grades = []string{"kg", "class-1", "class-2", "class-3"}

// GradeRank is a class's place in [Grades] (KG = 0), or -1 for an unknown id.
func GradeRank(g string) int {
	for i, x := range Grades {
		if x == g {
			return i
		}
	}
	return -1
}

func ValidGrade(g string) bool { return GradeRank(g) >= 0 }

// GradeList is "kg, class-1, class-2 or class-3", for messages.
func GradeList() string {
	return strings.Join(Grades[:len(Grades)-1], ", ") + " or " + Grades[len(Grades)-1]
}

// GradeForAge is the usual class at an age (5 KG, 6 Class 1, 7 Class 2,
// 8 Class 3), for children added before the app asked for the class.
func GradeForAge(age int) string { return Grades[min(max(age-5, 0), len(Grades)-1)] }

// ChangeGrade applies a parent's change to a child's class [grade] and the
// highest class open to them [open]. A new class opens only the classes up
// to it (higher ones lock again); [toOpen] opens classes up to it, never
// below the class.
func ChangeGrade(grade, open string, toGrade, toOpen *string) (string, string, error) {
	if toGrade != nil {
		if !ValidGrade(*toGrade) {
			return "", "", Invalid("grade must be " + GradeList())
		}
		if *toGrade != grade {
			grade, open = *toGrade, *toGrade
		}
	}
	if toOpen != nil {
		switch {
		case !ValidGrade(*toOpen):
			return "", "", Invalid("unlockedGrade must be " + GradeList())
		case GradeRank(*toOpen) < GradeRank(grade):
			return "", "", Invalid("unlockedGrade cannot be below the child's grade")
		}
		open = *toOpen
	}
	return grade, open, nil
}

// Ladder is a course's map levels by class: Ladder[n-1] is the class rank
// of level n. Classes only go up along the map (the catalog checks it).
type Ladder []int

// Unlocked: may a child in class [grade], with every class up to [open]
// open (their own class, or a higher one a parent opened), play [level]?
//
//   - a level of a lower class: yes (revision, never needed to go on)
//   - a level of a class above [open]: no, not even one played before
//   - otherwise in order: the first level of the child's class, a level
//     already finished, or the one after a finished level
//
// A course that starts above the child's class starts them at its first
// class.
func (l Ladder) Unlocked(level int, grade, open string, done func(n int) bool) bool {
	if level < 1 || level > len(l) {
		return false
	}
	g, o := l.span(grade, open)
	switch r := l[level-1]; {
	case r < g:
		return true
	case r > o:
		return false
	}
	return level == l.Start(g) || done(level) || done(level-1)
}

// Start is the first level of class rank [g] or a higher class (past the
// last level when there is none).
func (l Ladder) Start(g int) int {
	for i, r := range l {
		if r >= g {
			return i + 1
		}
	}
	return len(l) + 1
}

// span is the child's class and highest open class as ranks on this course.
func (l Ladder) span(grade, open string) (g, o int) {
	g = GradeRank(grade)
	if len(l) > 0 {
		g = max(g, l[0])
	}
	return g, max(GradeRank(open), g)
}
