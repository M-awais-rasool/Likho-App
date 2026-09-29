package main

// End-to-end tests of the API on a real Postgres (TEST_DATABASE_URL) with an
// in-memory Redis. Skipped when TEST_DATABASE_URL is not set:
//
//   TEST_DATABASE_URL=postgres://likho@localhost:5432/likho_test?sslmode=disable go test ./...

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	"likho/backend/database"
	"likho/backend/handlers"
	"likho/backend/repository"
	"likho/backend/routes"
	"likho/backend/services"
)

type testApp struct {
	t     *testing.T
	r     *gin.Engine
	redis *miniredis.Miniredis
}

func newTestApp(t *testing.T) *testApp {
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
		if s, err := db.DB(); err == nil {
			s.Close()
		}
	})

	store := repository.New(db)
	course := services.NewCourse(store)
	if err := course.Import(ctx, "../assets/data/course.json"); err != nil {
		t.Fatal(err)
	}
	if err := course.Reload(ctx); err != nil {
		t.Fatal(err)
	}
	tokens := services.Tokens{Secret: []byte("test-secret-test-secret-test-secret"), AccessTTL: 15 * time.Minute, RefreshTTL: time.Hour}
	h := &handlers.Handler{
		DB: db, Redis: rdb, Store: store,
		Auth:   services.Auth{Store: store, Google: services.DevGoogle{}, Tokens: tokens},
		Cache:  services.NewCache(rdb),
		Course: course,
	}
	return &testApp{t: t, r: routes.New(h, tokens), redis: mr}
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
	path := "/v1/children/" + id + "/results"
	want(t, a.do("POST", path, tok, map[string]any{"level": 2, "stars": 3}), http.StatusConflict, "level_locked")
	want(t, a.do("POST", path, tok, map[string]any{"level": 99, "stars": 3}), 400)
	want(t, a.do("POST", path, tok, map[string]any{"level": 1, "stars": 4}), 400)
	outcome := func(level, stars int) map[string]any {
		t.Helper()
		r := a.do("POST", path, tok, map[string]any{"level": level, "stars": stars})
		want(t, r, 200)
		return r.json()
	}
	if o := outcome(1, 2); o["gain"] != 4.0 || o["firstTime"] != true || o["totalStars"] != 4.0 {
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
	if ayaan["stars"] != 10.0 || ayaan["levelStars"].(map[string]any)["2"] != 3.0 || ayaan["daysPlayed"] != 1.0 {
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
			a.do("POST", "/v1/children/"+id+"/results", tok, map[string]any{"level": 1, "stars": 3})
		}()
	}
	wg.Wait()
	me := a.do("GET", "/v1/me", tok, nil).json()
	if s := me["children"].([]any)[0].(map[string]any)["stars"]; s != 5.0 {
		t.Fatalf("10 parallel first finishes of level 1 must give 3+2 = 5 stars once, got %v", s)
	}

	// 5 + 5 = 10 stars, the bow costs 6: only one of 10 parallel taps can buy it
	a.do("POST", "/v1/children/"+id+"/results", tok, map[string]any{"level": 2, "stars": 3})
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

func TestCourseRateLimitAndRedisDown(t *testing.T) {
	a := newTestApp(t)

	r := a.do("GET", "/v1/course", "", nil, "Accept-Encoding", "gzip")
	want(t, r, 200)
	if r.header.Get("Content-Encoding") != "gzip" || r.header.Get("ETag") == "" {
		t.Fatalf("headers: %v", r.header)
	}
	zr, err := gzip.NewReader(bytes.NewReader(r.body))
	if err != nil {
		t.Fatal(err)
	}
	var course map[string]any
	if err := json.NewDecoder(zr).Decode(&course); err != nil || len(course["levels"].([]any)) != 37 {
		t.Fatalf("course body: %v", err)
	}
	want(t, a.do("GET", "/v1/course", "", nil, "If-None-Match", r.header.Get("ETag")), http.StatusNotModified)

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
