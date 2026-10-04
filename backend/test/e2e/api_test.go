// Package e2e tests the whole API over HTTP on a real Postgres
// (TEST_DATABASE_URL) with an in-memory Redis. Skipped when
// TEST_DATABASE_URL is not set:
//
//	TEST_DATABASE_URL=postgres://likho@localhost:5432/likho_test?sslmode=disable go test ./...
package e2e

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"testing/fstest"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	"likho/backend/content"
	"likho/backend/internal/api/handler"
	"likho/backend/internal/app"
	"likho/backend/internal/catalog"
	"likho/backend/internal/database"
	"likho/backend/internal/service"
)

// course is the course the tests play.
const course = "english-handwriting"

type testApp struct {
	t     *testing.T
	r     http.Handler
	redis *miniredis.Miniredis
	built *app.Built
}

// newTestApp builds the API on a fresh database; [cat] replaces the real
// content.
func newTestApp(t *testing.T, cat ...*catalog.Catalog) *testApp {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	gin.SetMode(gin.TestMode)
	ctx := context.Background()
	db, err := database.Connect(ctx, url, false)
	if err != nil {
		t.Fatal(err)
	}
	// fresh schema for every test
	for _, sql := range []string{"DROP SCHEMA public CASCADE", "CREATE SCHEMA public"} {
		if err := db.Exec(sql).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err := database.Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() {
		rdb.Close()
		database.Close(db)
	})

	if len(cat) == 0 {
		real, err := catalog.Load(content.FS, catalog.Options{})
		if err != nil {
			t.Fatal(err)
		}
		cat = append(cat, real)
	}
	tokens := service.Tokens{Secret: []byte("test-secret-test-secret-test-secret"), AccessTTL: 15 * time.Minute, RefreshTTL: time.Hour}
	built := app.BuildApp(app.Deps{DB: db, Redis: rdb, Catalog: cat[0], Google: service.DevGoogle{}, Tokens: tokens, System: handler.SystemInfo{StartedAt: time.Now()}})
	return &testApp{t: t, r: built.Handler, redis: mr, built: built}
}

type res struct {
	status int
	header http.Header
	body   []byte
}

func (r res) json() map[string]any {
	var m map[string]any
	_ = json.Unmarshal(r.body, &m)
	return m
}

func (a *testApp) do(method, path, token string, body any, headers ...string) res {
	a.t.Helper()
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	w := httptest.NewRecorder()
	a.r.ServeHTTP(w, req)
	return res{w.Code, w.Header(), w.Body.Bytes()}
}

func (a *testApp) signIn(email string) (access, refresh string, out map[string]any) {
	a.t.Helper()
	r := a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:" + email})
	if r.status != http.StatusOK && r.status != http.StatusCreated {
		a.t.Fatalf("sign in: %d %s", r.status, r.body)
	}
	m := r.json()
	return m["accessToken"].(string), m["refreshToken"].(string), m
}

func want(t *testing.T, r res, status int, code ...string) {
	t.Helper()
	if r.status != status {
		t.Fatalf("status %d, want %d: %s", r.status, status, r.body)
	}
	if len(code) > 0 && r.json()["error"] != code[0] {
		t.Fatalf("error %v, want %s", r.json()["error"], code[0])
	}
}

func TestGoogleSignInCreatesOrContinues(t *testing.T) {
	a := newTestApp(t)

	r := a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:ammi@gmail.com"})
	want(t, r, http.StatusCreated)
	first := r.json()
	if first["isNewAccount"] != true {
		t.Fatal("first sign-in creates the account")
	}
	me := first["me"].(map[string]any)
	id := me["account"].(map[string]any)["id"]
	if s := me["settings"].(map[string]any); s["sessionMinutes"] != 10.0 || s["music"] != true {
		t.Errorf("default settings: %v", s)
	}

	r = a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:AMMI@gmail.com"})
	want(t, r, http.StatusOK)
	if r.json()["isNewAccount"] != false || r.json()["me"].(map[string]any)["account"].(map[string]any)["id"] != id {
		t.Fatal("same Google account continues the same Likho account")
	}

	want(t, a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "garbage"}), http.StatusUnauthorized, "invalid_google_token")
	want(t, a.do("POST", "/v1/auth/google", "", map[string]any{}), http.StatusBadRequest, "invalid_input")
	want(t, a.do("GET", "/v1/me", "", nil), http.StatusUnauthorized, "unauthorized")
	want(t, a.do("GET", "/v1/me", "nope", nil), http.StatusUnauthorized, "token_expired")
}

func TestChildrenProgressAndRoom(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")

	// children: validation, add up to 4
	want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": "", "age": 6, "color": "#FFC83D"}), 400)
	want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 9, "color": "#FFC83D"}), 400)
	want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#000000"}), 400)
	r := a.do("POST", "/v1/children", tok, map[string]any{"name": " Ayaan ", "age": 6, "color": "#ffc83d"})
	want(t, r, http.StatusCreated)
	kid := r.json()
	if kid["name"] != "Ayaan" || kid["color"] != "#FFC83D" || kid["stars"] != 0.0 {
		t.Fatalf("child: %v", kid)
	}
	id := kid["id"].(string)
	for _, n := range []string{"Zara", "Sara", "Ali"} {
		want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": n, "age": 5, "color": "#B79CED"}), http.StatusCreated)
	}
	want(t, a.do("POST", "/v1/children", tok, map[string]any{"name": "Five", "age": 5, "color": "#B79CED"}), http.StatusConflict, "too_many_children")

	// /me is cached, and a change drops the cache
	if h := a.do("GET", "/v1/me", tok, nil).header.Get("X-Cache"); h != "miss" {
		t.Errorf("first /me: %s", h)
	}
	if h := a.do("GET", "/v1/me", tok, nil).header.Get("X-Cache"); h != "hit" {
		t.Errorf("second /me: %s", h)
	}
	want(t, a.do("PATCH", "/v1/children/"+id, tok, map[string]any{"name": "Ayaan K"}), 200)
	if h := a.do("GET", "/v1/me", tok, nil).header.Get("X-Cache"); h != "miss" {
		t.Errorf("after a change /me is rebuilt: %s", h)
	}

	// results: locked levels, stars rules
	path := "/v1/children/" + id + "/courses/" + course + "/results"
	want(t, a.do("POST", path, tok, map[string]any{"level": 2, "stars": 3}), http.StatusConflict, "level_locked")
	want(t, a.do("POST", path, tok, map[string]any{"level": 99, "stars": 3}), 400, "invalid_input")
	want(t, a.do("POST", "/v1/children/"+id+"/courses/no-such-course/results", tok, map[string]any{"level": 1, "stars": 3}), 404, "course_not_found")
	want(t, a.do("POST", path, tok, map[string]any{"level": 1, "stars": 4}), 400)
	outcome := func(level, stars int) map[string]any {
		t.Helper()
		r := a.do("POST", path, tok, map[string]any{"level": level, "stars": stars})
		want(t, r, 200)
		return r.json()
	}
	if o := outcome(1, 2); o["gain"] != 4.0 || o["firstTime"] != true || o["totalStars"] != 4.0 || o["courseId"] != course {
		t.Errorf("first finish: +stars+2: %v", o)
	}
	if o := outcome(1, 3); o["gain"] != 1.0 || o["bestStars"] != 3.0 {
		t.Errorf("better: +1: %v", o)
	}
	if o := outcome(1, 1); o["gain"] != 0.0 || o["bestStars"] != 3.0 || o["totalStars"] != 5.0 {
		t.Errorf("worse: nothing, best kept: %v", o)
	}

	// idempotency: a retried request is answered again, stars awarded once
	first := a.do("POST", path, tok, map[string]any{"level": 2, "stars": 3}, "Idempotency-Key", "abc-1")
	want(t, first, 200)
	again := a.do("POST", path, tok, map[string]any{"level": 2, "stars": 3}, "Idempotency-Key", "abc-1")
	if again.status != 200 || again.header.Get("Idempotent-Replay") != "true" || !bytes.Equal(first.body, again.body) {
		t.Fatalf("replay: %d %s", again.status, again.body)
	}
	me := a.do("GET", "/v1/me", tok, nil).json()
	ayaan := me["children"].([]any)[0].(map[string]any)
	levelStars := ayaan["progress"].(map[string]any)[course].(map[string]any)["levelStars"].(map[string]any)
	if ayaan["stars"] != 10.0 || levelStars["2"] != 3.0 || ayaan["daysPlayed"] != 1.0 {
		t.Fatalf("progress in /me: %v", ayaan)
	}

	// Plus levels (13+) need the subscription
	for lvl := 3; lvl <= 12; lvl++ {
		outcome(lvl, 3)
	}
	want(t, a.do("POST", path, tok, map[string]any{"level": 13, "stars": 3}), http.StatusPaymentRequired, "plus_required")
	want(t, a.do("POST", "/v1/me/trial", tok, nil), 200)
	want(t, a.do("POST", "/v1/me/trial", tok, nil), http.StatusConflict, "trial_used")
	outcome(13, 2)

	// Mascot Room
	room := func(item string) res { return a.do("POST", "/v1/children/"+id+"/room/"+item, tok, nil) }
	stars := 10 + 10*5 + 4 // levels 3..12 first time with 3 stars, level 13 with 2
	want(t, room("dragon"), http.StatusNotFound, "unknown_item")
	r = room("party")
	want(t, r, 200)
	if st := r.json(); st["action"] != "bought" || st["stars"] != float64(stars-8) || st["wearing"] != "party" {
		t.Fatalf("buy: %v", st)
	}
	if st := room("party").json(); st["action"] != "taken_off" || st["wearing"] != nil {
		t.Fatalf("take off: %v", st)
	}
	if st := room("lamp").json(); st["action"] != "bought" || len(st["room"].([]any)) != 1 {
		t.Fatalf("furniture is placed when bought: %v", st)
	}
	if st := room("lamp").json(); st["action"] != "removed" || len(st["room"].([]any)) != 0 {
		t.Fatalf("remove: %v", st)
	}
	want(t, room("crown"), 200) // 46 - 40 = 6 stars left
	want(t, room("cape"), http.StatusConflict, "not_enough_stars")

	// settings
	want(t, a.do("PATCH", "/v1/me/settings", tok, map[string]any{"sessionMinutes": 7}), 400)
	r = a.do("PATCH", "/v1/me/settings", tok, map[string]any{"sessionMinutes": 15, "music": false})
	want(t, r, 200)
	if s := r.json(); s["sessionMinutes"] != 15.0 || s["music"] != false || s["sfx"] != true {
		t.Errorf("settings: %v", s)
	}

	// another parent cannot touch this child
	other, _, _ := a.signIn("someone@else.com")
	want(t, a.do("POST", path, other, map[string]any{"level": 1, "stars": 3}), 404)
	want(t, a.do("DELETE", "/v1/children/"+id, other, nil), 404)
	want(t, a.do("PATCH", "/v1/children/not-a-uuid", tok, map[string]any{}), 404)
}

func TestConcurrentRequestsNeverDoubleCount(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")
	id := a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#FFC83D"}).json()["id"].(string)

	var wg sync.WaitGroup
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			a.do("POST", "/v1/children/"+id+"/courses/"+course+"/results", tok, map[string]any{"level": 1, "stars": 3})
		}()
	}
	wg.Wait()
	me := a.do("GET", "/v1/me", tok, nil).json()
	if s := me["children"].([]any)[0].(map[string]any)["stars"]; s != 5.0 {
		t.Fatalf("10 parallel first finishes of level 1 must give 3+2 = 5 stars once, got %v", s)
	}

	// 5 + 5 = 10 stars, the bow costs 6: only one of 10 parallel taps can buy it
	a.do("POST", "/v1/children/"+id+"/courses/"+course+"/results", tok, map[string]any{"level": 2, "stars": 3})
	bought := make(chan int, 10)
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r := a.do("POST", "/v1/children/"+id+"/room/bow", tok, nil)
			if r.status == 200 && r.json()["action"] == "bought" {
				bought <- 1
			}
		}()
	}
	wg.Wait()
	close(bought)
	if n := len(bought); n != 1 {
		t.Fatalf("the bow is bought exactly once, got %d", n)
	}
}

func TestRefreshLogoutAndDelete(t *testing.T) {
	a := newTestApp(t)
	tok, refresh, _ := a.signIn("ammi@gmail.com")
	a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#FFC83D"})

	r := a.do("POST", "/v1/auth/refresh", "", map[string]any{"refreshToken": refresh})
	want(t, r, 200)
	pair := r.json()
	if pair["refreshToken"] == refresh || pair["accessToken"] == "" {
		t.Fatal("refresh rotates the token")
	}
	want(t, a.do("GET", "/v1/me", pair["accessToken"].(string), nil), 200)

	// the old refresh token was already used: treat it as stolen
	want(t, a.do("POST", "/v1/auth/refresh", "", map[string]any{"refreshToken": refresh}), 401, "session_reused")
	want(t, a.do("POST", "/v1/auth/refresh", "", map[string]any{"refreshToken": pair["refreshToken"]}), 401, "session_invalid")

	tok, refresh, _ = a.signIn("ammi@gmail.com")
	want(t, a.do("POST", "/v1/auth/logout", tok, nil), http.StatusNoContent)
	want(t, a.do("POST", "/v1/auth/refresh", "", map[string]any{"refreshToken": refresh}), 401)

	// the only child cannot be deleted; the account can
	tok, _, _ = a.signIn("ammi@gmail.com")
	kid := a.do("GET", "/v1/me", tok, nil).json()["children"].([]any)[0].(map[string]any)["id"].(string)
	want(t, a.do("DELETE", "/v1/children/"+kid, tok, nil), http.StatusConflict, "last_child")
	want(t, a.do("DELETE", "/v1/me", tok, nil), http.StatusNoContent)
	want(t, a.do("GET", "/v1/me", tok, nil), http.StatusUnauthorized, "account_deleted")
	_, _, again := a.signIn("ammi@gmail.com")
	if again["isNewAccount"] != true {
		t.Error("signing in after deleting starts a new account")
	}
}

func TestCoursesRateLimitAndRedisDown(t *testing.T) {
	a := newTestApp(t)

	list := a.do("GET", "/v1/courses", "", nil)
	want(t, list, 200)
	courses := list.json()["courses"].([]any)
	if len(courses) != 1 || courses[0].(map[string]any)["id"] != course || courses[0].(map[string]any)["levels"] != 36.0 {
		t.Fatalf("catalog: %s", list.body)
	}
	want(t, a.do("GET", "/v1/courses/nope", "", nil), 404, "course_not_found")
	want(t, a.do("GET", "/v1/courses/NOT..valid", "", nil), 404, "course_not_found")

	r := a.do("GET", "/v1/courses/"+course, "", nil, "Accept-Encoding", "gzip")
	want(t, r, 200)
	if r.header.Get("Content-Encoding") != "gzip" || r.header.Get("ETag") == "" {
		t.Fatalf("headers: %v", r.header)
	}
	zr, err := gzip.NewReader(bytes.NewReader(r.body))
	if err != nil {
		t.Fatal(err)
	}
	var doc map[string]any
	if err := json.NewDecoder(zr).Decode(&doc); err != nil || len(doc["levels"].([]any)) != 37 || doc["courseId"] != course {
		t.Fatalf("course body: %v", err)
	}
	if r.header.Get("ETag") != `"`+courses[0].(map[string]any)["version"].(string)+`"` {
		t.Error("the catalog version is the course ETag")
	}
	want(t, a.do("GET", "/v1/courses/"+course, "", nil, "If-None-Match", r.header.Get("ETag")), http.StatusNotModified)

	// sign-in is limited to 30 a minute per IP
	limited := false
	for i := range 35 {
		if a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": fmt.Sprintf("dev:kid%d@x.com", i)}).status == http.StatusTooManyRequests {
			limited = true
		}
	}
	if !limited {
		t.Error("rate limit")
	}

	// Redis down: the API keeps working from Postgres
	a.redis.FlushAll()
	a.redis.SetError("server down")
	r = a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:ammi@gmail.com"})
	want(t, r, http.StatusCreated)
	want(t, a.do("GET", "/v1/me", r.json()["accessToken"].(string), nil), 200)
	a.redis.SetError("")
}

// withSecondCourse is the real content plus a small second course.
func withSecondCourse(t *testing.T) *catalog.Catalog {
	t.Helper()
	fsys := fstest.MapFS{}
	err := fs.WalkDir(content.FS, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := fs.ReadFile(content.FS, p)
		fsys[p] = &fstest.MapFile{Data: b}
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	level := func(n int) []byte {
		return []byte(fmt.Sprintf(`{"id":"u-%d","number":%d,"name":"Urdu %d","skill":"s","icon":"edit","isBoss":false,"requiresSubscription":false,
			"intro":{"text":"ا","word":"alif","picture":null},"presentation":{},
			"rounds":[{"id":"u-%d-r1","type":"pick","prompt":{"text":"Find alif"},"pick":{"options":[{"id":"o1","label":"ا"}],"answer":{"kind":"label","value":"ا"}}}]}`, n, n, n, n))
	}
	fsys["courses/urdu-letters/course.json"] = &fstest.MapFile{Data: []byte(`{"id":"urdu-letters","title":"Urdu Letters","locale":"ur","status":"published","schemaVersion":1,"updatedAt":"2026-09-29T00:00:00Z"}`)}
	fsys["courses/urdu-letters/glyphs.json"] = &fstest.MapFile{Data: []byte(`{"glyphs":{}}`)}
	fsys["courses/urdu-letters/worlds/01-huroof/world.json"] = &fstest.MapFile{Data: []byte(`{"id":"huroof","order":1,"name":"Huroof","skill":"s","icon":"grass","themeId":"letterLand","boss":{"id":"snail","name":"Ghonga"}}`)}
	fsys["courses/urdu-letters/worlds/01-huroof/levels/01-alif.json"] = &fstest.MapFile{Data: level(1)}
	fsys["courses/urdu-letters/worlds/01-huroof/levels/02-bay.json"] = &fstest.MapFile{Data: level(2)}
	cat, err := catalog.Load(fsys, catalog.Options{})
	if err != nil {
		t.Fatal(err)
	}
	return cat
}

func TestEachCourseHasItsOwnProgress(t *testing.T) {
	a := newTestApp(t, withSecondCourse(t))
	tok, _, _ := a.signIn("ammi@gmail.com")
	id := a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#FFC83D"}).json()["id"].(string)
	results := func(c string) string { return "/v1/children/" + id + "/courses/" + c + "/results" }

	if n := len(a.do("GET", "/v1/courses", "", nil).json()["courses"].([]any)); n != 2 {
		t.Fatalf("two courses in the catalog, got %d", n)
	}
	want(t, a.do("POST", results(course), tok, map[string]any{"level": 1, "stars": 3}), 200)
	want(t, a.do("POST", results(course), tok, map[string]any{"level": 2, "stars": 3}), 200)
	// level 2 of the other course is still locked: unlocks are per course
	want(t, a.do("POST", results("urdu-letters"), tok, map[string]any{"level": 2, "stars": 3}), http.StatusConflict, "level_locked")
	want(t, a.do("POST", results("urdu-letters"), tok, map[string]any{"level": 3, "stars": 3}), 400, "invalid_input")
	r := a.do("POST", results("urdu-letters"), tok, map[string]any{"level": 1, "stars": 2})
	want(t, r, 200)
	if o := r.json(); o["firstTime"] != true || o["totalStars"] != 14.0 {
		t.Fatalf("stars are shared by all courses (5 + 5 + 4): %v", o)
	}

	kid := a.do("GET", "/v1/me", tok, nil).json()["children"].([]any)[0].(map[string]any)
	progress := kid["progress"].(map[string]any)
	eh := progress[course].(map[string]any)["levelStars"].(map[string]any)
	ur := progress["urdu-letters"].(map[string]any)["levelStars"].(map[string]any)
	if len(eh) != 2 || len(ur) != 1 || ur["1"] != 2.0 {
		t.Fatalf("progress per course: %v", progress)
	}
}

func TestRoomTapsAreIdempotentToo(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")
	id := a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#FFC83D"}).json()["id"].(string)
	for level := 1; level <= 2; level++ { // 5 + 5 stars
		a.do("POST", "/v1/children/"+id+"/courses/"+course+"/results", tok, map[string]any{"level": level, "stars": 3})
	}

	first := a.do("POST", "/v1/children/"+id+"/room/bow", tok, nil, "Idempotency-Key", "tap-1")
	want(t, first, 200)
	again := a.do("POST", "/v1/children/"+id+"/room/bow", tok, nil, "Idempotency-Key", "tap-1")
	if again.header.Get("Idempotent-Replay") != "true" || !bytes.Equal(first.body, again.body) {
		t.Fatalf("replayed: %s", again.body)
	}
	// without the key the second tap takes the bow off
	if st := a.do("POST", "/v1/children/"+id+"/room/bow", tok, nil).json(); st["action"] != "taken_off" {
		t.Fatalf("second tap: %v", st)
	}
	// a failed request frees its key
	want(t, a.do("POST", "/v1/children/"+id+"/room/crown", tok, nil, "Idempotency-Key", "tap-2"), http.StatusConflict, "not_enough_stars")
	want(t, a.do("POST", "/v1/children/"+id+"/room/crown", tok, nil, "Idempotency-Key", "tap-2"), http.StatusConflict, "not_enough_stars")
}
