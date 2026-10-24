package e2e

import (
	"net/http"
	"testing"
)

// App controls: what the admin panel switches on and off, as the app gets
// it (GET /v1/config) and as the server enforces it (levels, the trial,
// the Mascot Room).
func TestAppControls(t *testing.T) {
	a := newTestApp(t)
	adm := a.admin()

	// before anything is saved: the app as it was, stories still off
	r := a.do("GET", "/v1/config", "", nil)
	want(t, r, 200)
	cfg := r.json()
	if cfg["features"].(map[string]any)["stories"] != "off" || cfg["features"].(map[string]any)["room"] != "on" {
		t.Fatalf("default features: %v", cfg["features"])
	}
	billing := cfg["billing"].(map[string]any)
	if billing["freeLevels"] != 30.0 || billing["guestLevels"] != 1.0 || billing["enabled"] != true || billing["plusFree"] != false {
		t.Fatalf("default billing: %v", billing)
	}
	if bar := cfg["tabBar"].(map[string]any); bar["style"] != "candy" || bar["start"] != "map" || len(bar["tabs"].([]any)) != 4 {
		t.Fatalf("default bottom bar: %v", bar)
	}
	etag := r.header.Get("ETag")
	want(t, a.do("GET", "/v1/config", "", nil, "If-None-Match", etag), http.StatusNotModified)
	want(t, a.do("GET", "/v1/config", "garbage", nil), http.StatusUnauthorized, "token_expired")

	// the panel's page
	page := adm.json("GET", "/controls", nil, 200)
	saved := page["saved"].(map[string]any)
	meta := page["meta"].(map[string]any)
	if saved["revision"] != 0.0 || meta["lastLevel"].(float64) < 100 || len(meta["items"].([]any)) != 14 {
		t.Fatalf("controls page: revision %v, meta %v", saved["revision"], meta["lastLevel"])
	}
	c := saved["controls"].(map[string]any)
	c["features"].(map[string]any)["stories"] = "chosen"
	c["room"].(map[string]any)["items"].(map[string]any)["cap"] = map[string]any{"price": 3}
	c["room"].(map[string]any)["items"].(map[string]any)["crown"] = map[string]any{"hidden": true, "price": 40}
	b := c["billing"].(map[string]any)
	b["freeLevels"], b["trialLevels"], b["guestLevels"] = 5, 10, 2
	bar := c["tabBar"].(map[string]any)
	tabs := bar["tabs"].([]any)
	bar["style"], bar["tabs"] = "jelly", []any{tabs[2], tabs[0], tabs[1], tabs[3]} // Games first

	bad := map[string]any{}
	for k, v := range c {
		bad[k] = v
	}
	badBilling := map[string]any{}
	for k, v := range b {
		badBilling[k] = v
	}
	badBilling["trialLevels"] = 3
	bad["billing"] = badBilling
	want(t, adm.do("PUT", "/controls", map[string]any{"controls": bad, "revision": 0}), http.StatusBadRequest, "invalid_input")

	out := adm.json("PUT", "/controls", map[string]any{"controls": c, "revision": 0}, 200)
	if out["revision"] != 1.0 || out["updatedBy"] != ownerEmail {
		t.Fatalf("saved: %v", out)
	}
	// a save from the old revision would undo it unseen
	want(t, adm.do("PUT", "/controls", map[string]any{"controls": c, "revision": 0}), http.StatusConflict, "controls_changed")
	now := a.do("GET", "/v1/config", "", nil)
	if now.header.Get("ETag") == etag {
		t.Fatal("the app sees the change")
	}
	if bar := now.json()["tabBar"].(map[string]any); bar["style"] != "jelly" || bar["tabs"].([]any)[0].(map[string]any)["id"] != "games" {
		t.Fatalf("the app gets the new bottom bar: %v", bar)
	}

	// stories only for chosen families
	tokA, _, inA := a.signIn("ammi@gmail.com")
	idA := inA["me"].(map[string]any)["account"].(map[string]any)["id"].(string)
	tokB, _, _ := a.signIn("abbu@gmail.com")
	stories := func(tok string) any {
		t.Helper()
		r := a.do("GET", "/v1/config", tok, nil)
		want(t, r, 200)
		return r.json()["features"].(map[string]any)["stories"]
	}
	if stories(tokA) != "off" || stories("") != "off" {
		t.Fatal("chosen: off until the family is chosen")
	}
	sw := adm.do("PATCH", "/families/"+idA+"/features", map[string]any{"stories": true})
	want(t, sw, 200)
	if stories(tokA) != "on" || stories(tokB) != "off" || stories("") != "off" {
		t.Fatal("only the chosen family has stories")
	}
	want(t, adm.do("PATCH", "/families/"+idA+"/features", map[string]any{"rocket": true}), http.StatusBadRequest, "invalid_input")
	page = adm.json("GET", "/controls", nil, 200)
	if fams := page["meta"].(map[string]any)["families"].([]any); len(fams) != 1 || fams[0].(map[string]any)["key"] != "stories" {
		t.Fatalf("family counts: %v", fams)
	}
	want(t, adm.do("PATCH", "/families/"+idA+"/features", map[string]any{"stories": nil}), 200)
	if stories(tokA) != "off" {
		t.Fatal("following the controls again")
	}

	// the room at the new prices; hidden items cannot be bought
	kid := a.do("POST", "/v1/children", tokA, map[string]any{"name": "Sara", "age": 6, "color": "#FFC83D"})
	want(t, kid, http.StatusCreated)
	kidID := kid.json()["id"].(string)
	results := "/v1/children/" + kidID + "/courses/" + course + "/results"
	want(t, a.do("POST", results, tokA, map[string]any{"level": 1, "stars": 1}), 200) // 3 stars
	room := a.do("POST", "/v1/children/"+kidID+"/room/cap", tokA, nil)
	want(t, room, 200)
	if room.json()["stars"] != 0.0 || room.json()["action"] != "bought" {
		t.Fatalf("the cap costs 3 now: %v", room.json())
	}
	want(t, a.do("POST", "/v1/children/"+kidID+"/room/crown", tokA, nil), http.StatusNotFound, "item_unavailable")

	// free levels: 1..5; the trial opens up to 10
	for n := 2; n <= 5; n++ {
		want(t, a.do("POST", results, tokA, map[string]any{"level": n, "stars": 3}), 200)
	}
	want(t, a.do("POST", results, tokA, map[string]any{"level": 6, "stars": 3}), http.StatusPaymentRequired, "plus_required")
	want(t, a.do("POST", "/v1/me/trial", tokA, nil), 200)
	if s := a.do("GET", "/v1/me", tokA, nil).json()["subscription"].(map[string]any); s["trial"] != true || s["active"] != true {
		t.Fatalf("in the trial: %v", s)
	}
	for n := 6; n <= 10; n++ {
		want(t, a.do("POST", results, tokA, map[string]any{"level": n, "stars": 3}), 200)
	}
	want(t, a.do("POST", results, tokA, map[string]any{"level": 11, "stars": 3}), http.StatusPaymentRequired, "trial_limit")

	// a grant longer than the trial is not a trial any more
	adm.json("POST", "/families/"+idA+"/plus", map[string]any{"days": 30}, 200)
	if s := a.do("GET", "/v1/me", tokA, nil).json()["subscription"].(map[string]any); s["trial"] != false {
		t.Fatalf("granted Plus: %v", s)
	}
	want(t, a.do("POST", results, tokA, map[string]any{"level": 11, "stars": 3}), 200)

	// Plus that just ended still counts for the level being played
	if err := a.db.Exec("UPDATE parents SET plus_until = now() - interval '10 minutes' WHERE id = ?", idA).Error; err != nil {
		t.Fatal(err)
	}
	a.redis.FlushAll()
	want(t, a.do("POST", results, tokA, map[string]any{"level": 12, "stars": 3}), 200)
	if err := a.db.Exec("UPDATE parents SET plus_until = now() - interval '2 hours' WHERE id = ?", idA).Error; err != nil {
		t.Fatal(err)
	}
	want(t, a.do("POST", results, tokA, map[string]any{"level": 13, "stars": 3}), http.StatusPaymentRequired, "plus_required")

	// no server trial; billing off opens every level
	c = adm.json("GET", "/controls", nil, 200)["saved"].(map[string]any)["controls"].(map[string]any)
	b = c["billing"].(map[string]any)
	b["serverTrial"] = false
	adm.json("PUT", "/controls", map[string]any{"controls": c, "revision": 1}, 200)
	want(t, a.do("POST", "/v1/me/trial", tokB, nil), http.StatusConflict, "trial_unavailable")
	b["enabled"] = false
	adm.json("PUT", "/controls", map[string]any{"controls": c, "revision": 2}, 200)
	want(t, a.do("POST", results, tokA, map[string]any{"level": 13, "stars": 3}), 200)
	if a.do("GET", "/v1/config", "", nil).json()["billing"].(map[string]any)["plusFree"] != true {
		t.Fatal("plus free")
	}

	// every change is in the audit log
	audit := adm.do("GET", "/audit", nil)
	want(t, audit, 200)
	found := map[string]bool{}
	for _, e := range audit.json()["items"].([]any) {
		found[e.(map[string]any)["action"].(string)] = true
	}
	if !found["settings.app_controls"] || !found["family.features"] {
		t.Fatalf("audit: %v", found)
	}
}
