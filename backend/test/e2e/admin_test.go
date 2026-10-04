package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
)

const ownerEmail, ownerPassword = "owner@likho.test", "owner-password-1"

// adminClient is a browser signed in to the admin panel (its cookie).
type adminClient struct {
	a      *testApp
	cookie string
}

func (a *testApp) admin() *adminClient {
	a.t.Helper()
	if err := a.built.Admins.Bootstrap(context.Background(), ownerEmail, ownerPassword); err != nil {
		a.t.Fatal(err)
	}
	return a.adminLogin(ownerEmail, ownerPassword)
}

func (a *testApp) adminLogin(email, password string) *adminClient {
	a.t.Helper()
	r := a.do("POST", "/admin/api/v1/auth/login", "", map[string]any{"email": email, "password": password})
	want(a.t, r, http.StatusOK)
	for _, c := range r.header.Values("Set-Cookie") {
		if strings.HasPrefix(c, "likho_admin=") {
			if !strings.Contains(c, "HttpOnly") || !strings.Contains(c, "SameSite=Strict") {
				a.t.Errorf("admin cookie must be HttpOnly and SameSite=Strict: %s", c)
			}
			return &adminClient{a: a, cookie: strings.SplitN(c, ";", 2)[0]}
		}
	}
	a.t.Fatal("no admin cookie")
	return nil
}

func (c *adminClient) do(method, path string, body any) res {
	c.a.t.Helper()
	return c.a.do(method, "/admin/api/v1"+path, "", body, "Cookie", c.cookie, "X-Requested-With", "likho-admin")
}

func (c *adminClient) json(method, path string, body any, status int) map[string]any {
	c.a.t.Helper()
	r := c.do(method, path, body)
	want(c.a.t, r, status)
	return r.json()
}

func TestAdminSignInRolesAndCSRF(t *testing.T) {
	a := newTestApp(t)
	want(t, a.do("GET", "/admin/api/v1/overview", "", nil), http.StatusUnauthorized, "signed_out")
	owner := a.admin()
	want(t, a.do("POST", "/admin/api/v1/auth/login", "", map[string]any{"email": ownerEmail, "password": "wrong-password"}), http.StatusUnauthorized, "invalid_login")
	want(t, a.do("POST", "/admin/api/v1/auth/login", "", map[string]any{"email": "nobody@likho.test", "password": "wrong-password"}), http.StatusUnauthorized, "invalid_login")

	if me := owner.json("GET", "/auth/me", nil, 200)["admin"].(map[string]any); me["role"] != "owner" || me["email"] != ownerEmail {
		t.Fatalf("me: %v", me)
	}
	// a change without the CSRF header is refused
	want(t, a.do("PUT", "/admin/api/v1/settings/alerts", "", map[string]any{}, "Cookie", owner.cookie), http.StatusForbidden, "csrf")

	// team: a viewer reads but cannot change anything
	want(t, owner.do("POST", "/team", map[string]any{"email": "v@likho.test", "name": "Vee", "role": "viewer", "password": "short"}), 400)
	v := owner.json("POST", "/team", map[string]any{"email": "V@likho.test", "name": "Vee", "role": "viewer", "password": "viewer-password"}, 201)
	want(t, owner.do("POST", "/team", map[string]any{"email": "v@likho.test", "name": "Vee", "role": "viewer", "password": "viewer-password"}), http.StatusConflict, "admin_exists")
	viewer := a.adminLogin("v@likho.test", "viewer-password")
	want(t, viewer.do("GET", "/overview", nil), 200)
	want(t, viewer.do("PUT", "/settings/alerts", map[string]any{"reachedEnd": true}), http.StatusForbidden, "forbidden")
	want(t, viewer.do("GET", "/team", nil), http.StatusForbidden, "forbidden")

	// the last owner stays
	ownerID := owner.json("GET", "/auth/me", nil, 200)["admin"].(map[string]any)["id"].(string)
	want(t, owner.do("PATCH", "/team/"+ownerID, map[string]any{"role": "editor"}), http.StatusConflict, "last_owner")

	// disabling signs them out
	owner.json("PATCH", "/team/"+v["id"].(string), map[string]any{"disabled": true}, 200)
	want(t, viewer.do("GET", "/overview", nil), http.StatusUnauthorized, "signed_out")

	// audit log has the changes
	items := owner.json("GET", "/audit", nil, 200)["items"].([]any)
	actions := map[string]bool{}
	for _, it := range items {
		actions[it.(map[string]any)["action"].(string)] = true
	}
	for _, want := range []string{"admin.login", "team.added", "team.updated"} {
		if !actions[want] {
			t.Errorf("audit log misses %s: %v", want, actions)
		}
	}

	owner.do("POST", "/auth/logout", nil)
	want(t, owner.do("GET", "/auth/me", nil), http.StatusUnauthorized)
}

func TestAdminSeesFamiliesProgressAndEndAlerts(t *testing.T) {
	a := newTestApp(t)
	adm := a.admin()

	// a family in Pakistan on an iPhone
	r := a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:ammi@gmail.com"},
		"X-Likho-Region", "pk", "X-Likho-Platform", "iOS", "X-Likho-App-Version", "1.2.0+7")
	want(t, r, http.StatusCreated)
	tok := r.json()["accessToken"].(string)
	parentID := r.json()["me"].(map[string]any)["account"].(map[string]any)["id"].(string)
	r = a.do("POST", "/v1/children", tok, map[string]any{"name": "Ayaan", "age": 6, "color": "#FFC83D"})
	want(t, r, http.StatusCreated)
	childID := r.json()["id"].(string)

	// Plus levels need the subscription: the team grants it
	sub := adm.json("POST", "/families/"+parentID+"/plus", map[string]any{"days": 30}, 200)
	if sub["active"] != true {
		t.Fatalf("plus granted: %v", sub)
	}

	cc := adm.json("GET", "/content/courses/"+course, nil, 200)
	last := int(cc["liveLevels"].(float64))
	path := "/v1/children/" + childID + "/courses/" + course + "/results"
	play := func(level int) {
		t.Helper()
		want(t, a.do("POST", path, tok, map[string]any{"level": level, "stars": 3, "seconds": 90}), 200)
	}
	for n := 1; n < last; n++ {
		play(n)
	}

	// on the last level: one alert
	alerts := adm.json("GET", "/alerts?unread=1", nil, 200)["items"].([]any)
	if len(alerts) != 1 || alerts[0].(map[string]any)["kind"] != "reached_end" {
		t.Fatalf("one reached_end alert: %v", alerts)
	}
	if al := alerts[0].(map[string]any); !strings.Contains(al["title"].(string), "Ayaan reached the last level") || al["country"] != "PK" {
		t.Errorf("alert says who and where: %v", al)
	}
	play(last - 1) // a replay raises nothing new
	play(last)
	unread := adm.json("GET", "/alerts/unread", nil, 200)
	if unread["count"] != 2.0 {
		t.Fatalf("finishing the course alerts too: %v", unread)
	}

	// families: country, device, progress
	fam := adm.json("GET", "/families?q=AMMI", nil, 200)
	if fam["total"] != 1.0 {
		t.Fatalf("search by email: %v", fam)
	}
	f := fam["items"].([]any)[0].(map[string]any)
	if f["country"] != "PK" || f["countrySource"] != "device" || f["platform"] != "ios" || f["appVersion"] != "1.2.0+7" ||
		f["levels"] != float64(last) || f["starsEarned"] != float64(3*last) || f["topLevel"] != float64(last) {
		t.Errorf("family row: %v", f)
	}
	if adm.json("GET", "/families?country=GB", nil, 200)["total"] != 0.0 {
		t.Error("country filter")
	}
	detail := adm.json("GET", "/families/"+parentID, nil, 200)
	if kids := detail["children"].([]any); len(kids) != 1 || len(detail["activity"].([]any)) == 0 || len(detail["devices"].([]any)) != 1 {
		t.Errorf("family detail: children, activity, devices: %v", detail)
	}

	// learners and the dashboard
	if l := adm.json("GET", "/learners?filter=finished", nil, 200); l["total"] != 1.0 {
		t.Errorf("finished learners: %v", l)
	}
	ov := adm.json("GET", "/overview?days=7", nil, 200)
	tot := ov["totals"].(map[string]any)
	if tot["parents"] != 1.0 || tot["children"] != 1.0 || tot["activeToday"] != 1.0 || tot["finished"] != 1.0 ||
		tot["levelsCompleted"] != float64(last) || tot["plus"] != 1.0 || tot["countries"] != 1.0 {
		t.Errorf("totals: %v", tot)
	}
	if s := ov["series"].([]any); len(s) != 7 || s[6].(map[string]any)["signups"] != 1.0 {
		t.Errorf("series: %v", s)
	}
	stats := adm.json("GET", "/levels/stats", nil, 200)
	if l1 := stats["levels"].([]any)[0].(map[string]any); l1["children"] != 1.0 || l1["avgSeconds"] != 90.0 || stats["finished"] != 1.0 {
		t.Errorf("level stats: %v", stats)
	}

	// activity feed, newest first, filtered
	feed := adm.json("GET", "/activity?types=course_completed,signed_up", nil, 200)["items"].([]any)
	if len(feed) != 2 || feed[0].(map[string]any)["type"] != "course_completed" || feed[0].(map[string]any)["childName"] != "Ayaan" {
		t.Errorf("feed: %v", feed)
	}

	// support actions
	if s := adm.json("POST", "/children/"+childID+"/stars", map[string]any{"delta": -100000}, 400); s == nil {
		t.Error("limits")
	}
	stars := adm.json("POST", "/children/"+childID+"/stars", map[string]any{"delta": 10, "reason": "sorry"}, 200)["stars"].(float64)
	me := a.do("GET", "/v1/me", tok, nil).json()
	if me["children"].([]any)[0].(map[string]any)["stars"] != stars {
		t.Errorf("the app sees the new balance at once (cache dropped)")
	}
	adm.json("POST", "/alerts/read", map[string]any{}, 204)
	if adm.json("GET", "/alerts/unread", nil, 200)["count"] != 0.0 {
		t.Error("all read")
	}
	csv := adm.do("GET", "/families.csv", nil)
	if csv.status != 200 || !strings.Contains(string(csv.body), "ammi@gmail.com") {
		t.Errorf("csv export: %d %s", csv.status, csv.body)
	}
	want(t, adm.do("POST", "/families/"+parentID+"/sign-out", nil), 204)
	want(t, adm.do("DELETE", "/families/"+parentID, nil), 204)
	want(t, a.do("GET", "/v1/me", tok, nil), http.StatusUnauthorized, "account_deleted")
	if adm.json("GET", "/overview", nil, 200)["totals"].(map[string]any)["parents"] != 0.0 {
		t.Error("deleted")
	}
}

// newLevel is level [from]'s document as level [n] (new ids).
func newLevel(t *testing.T, adm *adminClient, from, n int, name string) string {
	t.Helper()
	doc := adm.json("GET", fmt.Sprintf("/content/courses/%s/levels/%d", course, from), nil, 200)["doc"].(string)
	doc = strings.ReplaceAll(doc, fmt.Sprintf("level-%02d", from), fmt.Sprintf("level-%02d", n))
	var m map[string]any
	if err := json.Unmarshal([]byte(doc), &m); err != nil {
		t.Fatal(err)
	}
	m["number"], m["name"], m["isBoss"] = n, name, false
	b, _ := json.Marshal(m)
	return string(b)
}

func TestAdminAddsEditsAndPublishesLevels(t *testing.T) {
	a := newTestApp(t)
	adm := a.admin()
	cc := adm.json("GET", "/content/courses/"+course, nil, 200)
	last := int(cc["liveLevels"].(float64))
	next := int(cc["nextNumber"].(float64))
	worlds := cc["worlds"].([]any)
	lastWorld := worlds[len(worlds)-1].(map[string]any)["folder"].(string)
	if next != last+1 {
		t.Fatalf("next number: %v", cc)
	}

	// problems are listed, nothing is saved
	bad := adm.do("POST", "/content/courses/"+course+"/levels/validate", map[string]any{"number": next, "world": lastWorld, "doc": `{"number": 1}`})
	want(t, bad, http.StatusUnprocessableEntity, "content_invalid")
	if p := bad.json()["problems"].([]any); len(p) == 0 {
		t.Fatal("problems listed")
	}
	dup := strings.ReplaceAll(newLevel(t, adm, last, next, "Moon Race"), fmt.Sprintf("level-%02d", next), fmt.Sprintf("level-%02d", last))
	r := adm.do("POST", "/content/courses/"+course+"/levels", map[string]any{"number": next, "world": lastWorld, "doc": dup})
	want(t, r, http.StatusUnprocessableEntity)
	if !strings.Contains(string(r.body), "is also used by") {
		t.Errorf("duplicate ids are a problem: %s", r.body)
	}

	// a new level: a draft first, phones do not see it
	doc := newLevel(t, adm, last, next, "Moon Race")
	want(t, adm.do("POST", "/content/courses/"+course+"/levels/validate", map[string]any{"number": next, "world": lastWorld, "doc": doc}), 200)
	lv := adm.json("POST", "/content/courses/"+course+"/levels", map[string]any{"number": next, "world": lastWorld, "doc": doc}, 201)
	if lv["status"] != "draft" || lv["source"] != "new" || lv["name"] != "Moon Race" {
		t.Fatalf("draft: %v", lv)
	}
	served := func() map[string]any {
		t.Helper()
		r := a.do("GET", "/v1/courses", "", nil)
		want(t, r, 200)
		return r.json()["courses"].([]any)[0].(map[string]any)
	}
	before := served()
	if before["levels"] != float64(last) {
		t.Fatalf("drafts are not served: %v", before)
	}
	staged := adm.do("GET", "/content/courses/"+course+"/document", nil)
	if !strings.Contains(string(staged.body), "Moon Race") {
		t.Error("the preview document has the draft")
	}

	// publish: phones get it (new version), and children can play it
	lv = adm.json("POST", fmt.Sprintf("/content/courses/%s/levels/%d/publish", course, next), nil, 200)
	if lv["status"] != "live" {
		t.Fatalf("published: %v", lv)
	}
	after := served()
	if after["levels"] != float64(next) || after["version"] == before["version"] {
		t.Fatalf("published level served with a new version: %v", after)
	}
	body := a.do("GET", "/v1/courses/"+course, "", nil)
	if !strings.Contains(string(body.body), "Moon Race") {
		t.Error("course document has the new level")
	}

	// an edit of a published level waits until it is published again
	edited := strings.Replace(doc, "Moon Race", "Moon Dash", 1)
	lv = adm.json("PUT", fmt.Sprintf("/content/courses/%s/levels/%d", course, next), map[string]any{"doc": edited}, 200)
	if lv["status"] != "changed" || !strings.Contains(*strPtr(lv["liveDoc"]), "Moon Race") {
		t.Errorf("changed: %v", lv["status"])
	}
	lv = adm.json("POST", fmt.Sprintf("/content/courses/%s/levels/%d/discard", course, next), nil, 200)
	if lv["status"] != "live" || lv["name"] != "Moon Race" {
		t.Errorf("discarded: %v", lv)
	}

	// a built-in level can be edited and reverted
	one := adm.json("GET", "/content/courses/"+course+"/levels/1", nil, 200)
	adm.json("PUT", "/content/courses/"+course+"/levels/1", map[string]any{"doc": strings.Replace(one["doc"].(string), `"Balloon Pop"`, `"Balloon Party"`, 1)}, 200)
	adm.json("POST", "/content/courses/"+course+"/levels/1/publish", nil, 200)
	if !strings.Contains(string(a.do("GET", "/v1/courses/"+course, "", nil).body), "Balloon Party") {
		t.Error("edited built-in level is live")
	}
	want(t, adm.do("POST", "/content/courses/"+course+"/levels/1/unpublish", nil), 400)
	want(t, adm.do("DELETE", "/content/courses/"+course+"/levels/1", nil), 204)
	if strings.Contains(string(a.do("GET", "/v1/courses/"+course, "", nil).body), "Balloon Party") {
		t.Error("reverted to the original")
	}

	// a new world, with a level of its own
	w := adm.json("POST", "/content/courses/"+course+"/worlds", map[string]any{
		"name": "Ocean Deep", "skill": "Reading", "icon": "waves", "themeId": "smallLetterCove", "bossId": "fish", "bossName": "Sleepy Whale"}, 200)
	want(t, adm.do("POST", "/content/courses/"+course+"/worlds", map[string]any{
		"name": "Too Soon", "icon": "waves", "themeId": "smallLetterCove", "bossId": "fish", "bossName": "X"}), 400)
	doc2 := newLevel(t, adm, last, next+1, "Whale Song")
	adm.json("POST", "/content/courses/"+course+"/levels", map[string]any{"number": next + 1, "world": w["folder"], "doc": doc2}, 201)
	adm.json("POST", fmt.Sprintf("/content/courses/%s/levels/%d/publish", course, next+1), nil, 200)
	if got := served(); got["worlds"] != float64(len(worlds)+1) || got["levels"] != float64(next+1) {
		t.Fatalf("new world served: %v", got)
	}

	// only the last level can be taken away, and only before it was played
	want(t, adm.do("POST", fmt.Sprintf("/content/courses/%s/levels/%d/unpublish", course, next), nil), 400) // not the last
	adm.json("POST", fmt.Sprintf("/content/courses/%s/levels/%d/unpublish", course, next+1), nil, 200)
	want(t, adm.do("DELETE", fmt.Sprintf("/content/courses/%s/levels/%d", course, next), nil), 400) // live
	want(t, adm.do("DELETE", fmt.Sprintf("/content/courses/%s/levels/%d", course, next+1), nil), 204)
	want(t, adm.do("DELETE", "/content/courses/"+course+"/worlds/"+w["folder"].(string), nil), 204)
	if got := served(); got["levels"] != float64(next) || got["worlds"] != float64(len(worlds)) {
		t.Fatalf("after unpublish: %v", got)
	}

	// the audit log has every content change
	items := adm.json("GET", "/audit?limit=100", nil, 200)["items"].([]any)
	n := 0
	for _, it := range items {
		if strings.HasPrefix(it.(map[string]any)["action"].(string), "content.") {
			n++
		}
	}
	if n < 8 {
		t.Errorf("content changes audited: %d", n)
	}
}

func strPtr(v any) *string {
	s, _ := v.(string)
	return &s
}
