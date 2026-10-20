package domain

import (
	"strings"
	"time"
)

const (
	MaxChildren = 4
	TrialDays   = 7

	MinStars = 1
	MaxStars = 3

	// DefaultLevelSeconds is counted when the app does not send the time a
	// level took (the prototype counts 3 minutes); MaxLevelSeconds caps it.
	DefaultLevelSeconds = 180
	MaxLevelSeconds     = 1800
)

// PlusGrace: a level finished this long after Likho Plus ended (e.g. the
// trial ran out while the child played) still counts.
const PlusGrace = MaxLevelSeconds * time.Second

// Gain = stars added for finishing a level: the improvement over the best
// result so far, plus 2 the first time (the app's FamilyNotifier.recordResult).
func Gain(old *int, stars int) int {
	if old == nil {
		return stars + 2
	}
	return max(0, stars-*old)
}

// Unlocked: the first level, any level already finished, or the one after
// a finished level.
func Unlocked(level int, done func(n int) bool) bool {
	return level <= 1 || done(level) || done(level-1)
}

// ValidStars: a finished level earns 1 to 3 stars.
func ValidStars(s int) bool { return s >= MinStars && s <= MaxStars }

// LevelSeconds normalises the time a level took.
func LevelSeconds(s int) int {
	if s <= 0 {
		return DefaultLevelSeconds
	}
	return min(s, MaxLevelSeconds)
}

// PencilColors are the six body colours the app offers.
var PencilColors = map[string]bool{
	"#FFC83D": true, // yellow
	"#4D9DE0": true, // blue
	"#3BB273": true, // green
	"#FF8A5B": true, // coral
	"#B79CED": true, // purple
	"#FF9EB5": true, // pink
}

func ValidColor(c string) bool { return PencilColors[strings.ToUpper(c)] }

func ValidAge(a int) bool { return a >= 5 && a <= 8 }

// CleanName trims a child's name; ok = 1..14 characters.
func CleanName(n string) (string, bool) {
	n = strings.TrimSpace(n)
	l := len([]rune(n))
	return n, l >= 1 && l <= 14
}

func ValidSessionMinutes(m int) bool { return m == 5 || m == 10 || m == 15 }
