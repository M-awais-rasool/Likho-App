package e2e

import (
	"context"
	"net/http"
	"testing"

	"likho/backend/internal/app"
	"likho/backend/internal/repository"
)

// child returns the child [id] as GET /v1/me shows it.
func (a *testApp) child(tok, id string) map[string]any {
	a.t.Helper()
	for _, c := range a.do("GET", "/v1/me", tok, nil).json()["children"].([]any) {
		if k := c.(map[string]any); k["id"] == id {
			return k
		}
	}
	a.t.Fatalf("child %s is not in /me", id)
	return nil
}

func TestClassZones(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")
	r := a.do("POST", "/v1/children", tok, map[string]any{"name": "Zara", "grade": "class-1", "color": "#B79CED"})
	want(t, r, http.StatusCreated)
	id := r.json()["id"].(string)
	want(t, a.do("POST", "/v1/me/trial", tok, nil), 200) // levels 13+ are Likho Plus

	path := "/v1/children/" + id + "/courses/" + course + "/results"
	play := func(level, status int, code ...string) {
		t.Helper()
		want(t, a.do("POST", path, tok, map[string]any{"level": level, "stars": 3}), status, code...)
	}
	patch := func(body map[string]any) map[string]any {
		t.Helper()
		r := a.do("PATCH", "/v1/children/"+id, tok, body)
		want(t, r, 200)
		return r.json()
	}

	// Class 1: KG is revision (any level, in any order), Class 1 starts at 13
	play(5, 200)
	play(13, 200)
	play(15, http.StatusConflict, "level_locked") // in order within the class
	play(25, http.StatusConflict, "level_locked") // Class 2 waits for a parent
	for level := 14; level <= 24; level++ {
		play(level, 200)
	}
	play(25, http.StatusConflict, "level_locked") // finishing the class does not open the next

	// a parent opens Class 2 (never below the child's own class)
	want(t, a.do("PATCH", "/v1/children/"+id, tok, map[string]any{"unlockedGrade": "kg"}), 400, "invalid_input")
	want(t, a.do("PATCH", "/v1/children/"+id, tok, map[string]any{"unlockedGrade": "class-5"}), 400, "invalid_input")
	confirmedAt := a.child(tok, id)["gradeConfirmedAt"]
	if k := patch(map[string]any{"unlockedGrade": "class-2"}); k["grade"] != "class-1" || k["unlockedGrade"] != "class-2" || k["gradeConfirmedAt"] != confirmedAt {
		t.Fatalf("opening a class is not a class change: %v", k)
	}
	play(25, 200)
	play(31, http.StatusConflict, "level_locked")

	// moved down to KG: higher classes lock again, their stars stay
	k := patch(map[string]any{"grade": "kg"})
	if k["grade"] != "kg" || k["unlockedGrade"] != "kg" || k["gradeConfirmedAt"] == confirmedAt {
		t.Fatalf("a new class: %v", k)
	}
	play(13, http.StatusConflict, "level_locked")
	play(3, http.StatusConflict, "level_locked") // KG is in order again: 1, 2 … (5 was played)
	play(1, 200)
	play(6, 200) // after the 5 played as revision
	stars := k["progress"].(map[string]any)[course].(map[string]any)["levelStars"].(map[string]any)
	if stars["13"] != 3.0 || stars["25"] != 3.0 {
		t.Fatalf("stars are never taken away: %v", stars)
	}

	// back to Class 1: its levels are open again, Class 2 is not
	if k := patch(map[string]any{"grade": "class-1"}); k["unlockedGrade"] != "class-1" {
		t.Fatalf("a new class opens only up to it: %v", k)
	}
	play(13, 200)
	play(26, http.StatusConflict, "level_locked")
}

func TestOlderAppsSendTheAge(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")
	r := a.do("POST", "/v1/children", tok, map[string]any{"name": "Ali", "age": 7, "color": "#3BB273"})
	want(t, r, http.StatusCreated)
	k := r.json()
	if k["age"] != 7.0 || k["grade"] != "class-2" || k["unlockedGrade"] != "class-2" || k["gradeConfirmedAt"] != nil {
		t.Fatalf("the class is guessed from the age and left for a parent to confirm: %v", k)
	}
	id := k["id"].(string)

	r = a.do("PATCH", "/v1/children/"+id, tok, map[string]any{"grade": "class-2"})
	want(t, r, 200)
	if k := r.json(); k["grade"] != "class-2" || k["gradeConfirmedAt"] == nil {
		t.Fatalf("sending the same class confirms it: %v", k)
	}
	r = a.do("PATCH", "/v1/children/"+id, tok, map[string]any{"age": 8, "name": "Ali K"})
	want(t, r, 200)
	if k := r.json(); k["age"] != 8.0 || k["grade"] != "class-2" || k["name"] != "Ali K" {
		t.Fatalf("an age change leaves the class alone: %v", k)
	}
}

func TestChildrenFromBeforeClassesGetAClass(t *testing.T) {
	a := newTestApp(t)
	tok, _, out := a.signIn("ammi@gmail.com")
	parent := out["me"].(map[string]any)["account"].(map[string]any)["id"].(string)
	exec := func(sql string, args ...any) {
		t.Helper()
		if err := a.db.Exec(sql, args...).Error; err != nil {
			t.Fatal(err)
		}
	}

	// the children table as it was before classes: age required, no class
	exec("ALTER TABLE children DROP COLUMN grade, DROP COLUMN unlocked_grade, DROP COLUMN grade_confirmed_at")
	exec("ALTER TABLE children ALTER COLUMN age SET NOT NULL")
	add := func(name string, age int) string {
		t.Helper()
		var id string
		err := a.db.Raw("INSERT INTO children (parent_id, name, age, color, created_at, updated_at) VALUES (?, ?, ?, '#FFC83D', now(), now()) RETURNING id",
			parent, name, age).Scan(&id).Error
		if err != nil {
			t.Fatal(err)
		}
		return id
	}
	ayaan, zara, ali := add("Ayaan", 5), add("Zara", 7), add("Ali", 6)
	for level := 1; level <= 14; level++ { // Ayaan (5) already plays Class 1
		exec("INSERT INTO level_progress (child_id, course_id, level, best_stars) VALUES (?, ?, ?, 3)", ayaan, course, level)
	}
	exec("INSERT INTO level_progress (child_id, course_id, level, best_stars) VALUES (?, 'old-course', 30, 3)", ali)

	// the new version starts
	if err := app.Migrate(context.Background(), a.db, a.cat); err != nil {
		t.Fatal(err)
	}
	for id, w := range map[string][2]string{ayaan: {"kg", "class-1"}, zara: {"class-2", "class-2"}, ali: {"class-1", "class-1"}} {
		k := a.child(tok, id)
		if k["grade"] != w[0] || k["unlockedGrade"] != w[1] || k["gradeConfirmedAt"] != nil {
			t.Errorf("%s: grade %v open %v confirmed %v, want %s up to %s, unconfirmed", k["name"], k["grade"], k["unlockedGrade"], k["gradeConfirmedAt"], w[0], w[1])
		}
	}
	// Ayaan keeps every level he had reached
	want(t, a.do("POST", "/v1/children/"+ayaan+"/courses/"+course+"/results", tok, map[string]any{"level": 14, "stars": 3}), http.StatusPaymentRequired, "plus_required")
	want(t, a.do("POST", "/v1/children/"+ayaan+"/courses/"+course+"/results", tok, map[string]any{"level": 12, "stars": 3}), 200)

	// a parent confirms the class
	r := a.do("PATCH", "/v1/children/"+ayaan, tok, map[string]any{"grade": "kg"})
	want(t, r, 200)
	if k := r.json(); k["gradeConfirmedAt"] == nil || k["unlockedGrade"] != "class-1" {
		t.Fatalf("confirming keeps what is open: %v", k)
	}
	// age is optional now
	want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": "Sara", "grade": "kg", "color": "#B79CED"}), http.StatusCreated)
	// and nothing is left to fill in
	if n, err := repository.New(a.db).Children.FillGrades(context.Background(), a.cat.Ladders()); n != 0 || err != nil {
		t.Fatalf("FillGrades again: %d %v", n, err)
	}
}
