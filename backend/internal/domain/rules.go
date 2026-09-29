// Package game holds Likho's rules, the same ones the Flutter app uses, so
// the server decides stars and purchases (a child cannot give themselves
// stars by editing the app).
package game

import "strings"

const (
	MaxChildren = 4
	FirstLevel  = 1
	LastLevel   = 36
	TrialDays   = 7
)

// Gain = stars added for finishing a level: the improvement over the best
// result so far, plus 2 the first time (FamilyNotifier.recordResult).
func Gain(old *int, stars int) int {
	if old == nil {
		return stars + 2
	}
	return max(0, stars-*old)
}

// Unlocked: level 1, any level already finished, or the one after a
// finished level.
func Unlocked(level int, done func(n int) bool) bool {
	return level <= FirstLevel || done(level) || done(level-1)
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
