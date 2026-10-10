package e2e

import (
	"net/http"
	"slices"
	"testing"
	"time"
)

// The Play closed test: testers are tracked by the Likho account they use
// (linked by email, or by the team), never by a device id; while the test
// runs, every account that uses the app gets Plus and every level open.
func TestClosedTestTracksTestersByAccount(t *testing.T) {
	a := newTestApp(t)
	adm := a.admin()
	karachi, err := time.LoadLocation("Asia/Karachi")
	if err != nil {
		t.Fatal(err)
	}
	today := time.Now().In(karachi).Format("2006-01-02")
	yesterday := time.Now().In(karachi).AddDate(0, 0, -1).Format("2006-01-02")
	signIn := func(email string) (token, parentID string, me map[string]any) {
		t.Helper()
		r := a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:" + email})
		if r.status != http.StatusCreated && r.status != http.StatusOK {
			t.Fatalf("sign in %s: %d %s", email, r.status, r.body)
		}
		me = r.json()["me"].(map[string]any)
		return r.json()["accessToken"].(string), me["account"].(map[string]any)["id"].(string), me
	}
	perks := func(me map[string]any) (plus, open bool) {
		return me["subscription"].(map[string]any)["active"] == true, me["account"].(map[string]any)["tester"] == true
	}
	board := func() map[string]any { t.Helper(); return adm.json("GET", "/closed-test", nil, 200) }
	ids := func(list any) []string {
		var out []string
		for _, x := range list.([]any) {
			out = append(out, x.(map[string]any)["parentId"].(string))
		}
		return out
	}
	days := func(x any) []string {
		var out []string
		for _, d := range x.([]any) {
			out = append(out, d.(string))
		}
		return out
	}

	// no test set up: the page works and nothing is counted or given
	if b := board(); b["endDate"] != "" || len(b["testers"].([]any)) != 0 || b["settings"].(map[string]any)["days"] != 14.0 {
		t.Fatalf("empty board: %v", b)
	}
	_, _, me := signIn("early@gmail.com")
	if plus, open := perks(me); plus || open || len(board()["newAccounts"].([]any)) != 0 {
		t.Fatal("counted before the test was set up")
	}

	// the test starts today, in Pakistan time
	want(t, adm.do("PUT", "/closed-test/settings", map[string]any{"startDate": today, "days": 14, "needed": 12, "timeZone": "Mars/Base"}), 400)
	s := adm.json("PUT", "/closed-test/settings", map[string]any{"startDate": today, "days": 14, "needed": 12, "timeZone": "Asia/Karachi", "plus": true, "openLevels": true}, 200)
	if s["plusUntil"] == "" || s["reminder"] == "" {
		t.Fatalf("settings defaults: %v", s)
	}

	// the testers as added in Play Console; the same Google account twice is skipped
	r := adm.json("POST", "/closed-test/testers", map[string]any{"testers": []map[string]any{
		{"name": "Ali Khan", "email": "Ali.Khan@Gmail.com", "phone": "0300 1234567"},
		{"name": "Sara", "email": "sara@outlook.com"},
		{"name": "Ali again", "email": "alikhan@gmail.com"},
	}}, 201)
	added := r["added"].([]any)
	if len(added) != 2 || r["skipped"] != 1.0 || added[0].(map[string]any)["phone"] != "923001234567" {
		t.Fatalf("testers: %v", r)
	}
	ali, sara := added[0].(map[string]any)["id"].(string), added[1].(map[string]any)["id"].(string)
	want(t, adm.do("POST", "/closed-test/testers", map[string]any{"testers": []map[string]any{{"name": ""}}}), 400)

	// Ali signs in with his Gmail spelt another way: linked on its own, with Plus and every level open
	aliToken, aliParent, me := signIn("a.li.khan+kids@gmail.com")
	if plus, open := perks(me); !plus || !open {
		t.Fatalf("Ali's perks: %v", me)
	}
	signIn("a.li.khan+kids@gmail.com") // again the same day: still one day

	// Sara uses another email: new until the team says whose it is (she gets the perks anyway)
	_, saraParent, me := signIn("sara.home@gmail.com")
	if plus, open := perks(me); !plus || !open {
		t.Fatalf("Sara's perks: %v", me)
	}
	b := board()
	if b["today"] != today || b["day"] != 1.0 || b["endDate"] == "" {
		t.Fatalf("board: today %v day %v end %v", b["today"], b["day"], b["endDate"])
	}
	if got := ids(b["newAccounts"]); !slices.Equal(got, []string{saraParent}) {
		t.Fatalf("new accounts: %v", got)
	}
	tAli := b["testers"].([]any)[0].(map[string]any)
	if acc := tAli["accounts"].([]any); len(acc) != 1 || acc[0].(map[string]any)["parentId"] != aliParent || acc[0].(map[string]any)["auto"] != true {
		t.Fatalf("Ali's accounts: %v", tAli)
	}
	if got := days(tAli["days"]); !slices.Equal(got, []string{today}) {
		t.Fatalf("Ali's days: %v", got)
	}

	want(t, adm.do("PUT", "/closed-test/accounts/"+saraParent, map[string]any{"testerId": "00000000-0000-0000-0000-000000000000"}), 404)
	want(t, adm.do("PUT", "/closed-test/accounts/"+saraParent, map[string]any{"testerId": sara}), 204)

	// the team's own phone is marked as not a tester
	_, teamParent, _ := signIn("team@likho.app")
	want(t, adm.do("PUT", "/closed-test/accounts/"+teamParent, map[string]any{"testerId": nil}), 204)

	// a day Ali used the app before, and his days stay merged across accounts
	if err := a.db.Exec("INSERT INTO closed_test_days (parent_id, day) VALUES (?, ?)", aliParent, yesterday).Error; err != nil {
		t.Fatal(err)
	}
	b = board()
	if len(b["newAccounts"].([]any)) != 0 || !slices.Equal(ids(b["notTesters"]), []string{teamParent}) {
		t.Fatalf("after linking: new %v, not testers %v", b["newAccounts"], b["notTesters"])
	}
	tAli, tSara := b["testers"].([]any)[0].(map[string]any), b["testers"].([]any)[1].(map[string]any)
	if got := days(tAli["days"]); !slices.Equal(got, []string{yesterday, today}) {
		t.Fatalf("Ali's days: %v", got)
	}
	if acc := tSara["accounts"].([]any); len(acc) != 1 || acc[0].(map[string]any)["parentId"] != saraParent || !slices.Equal(days(tSara["days"]), []string{today}) {
		t.Fatalf("Sara: %v", tSara)
	}

	// closing the levels for testers reaches the app
	s["openLevels"] = false
	adm.json("PUT", "/closed-test/settings", s, 200)
	if _, open := perks(a.do("GET", "/v1/me", aliToken, nil).json()); open {
		t.Fatal("levels still open for Ali")
	}

	// removing a tester lists their account as new again
	want(t, adm.do("DELETE", "/closed-test/testers/"+sara, nil), 204)
	want(t, adm.do("DELETE", "/closed-test/accounts/"+aliParent, nil), 204)
	b = board()
	if got := ids(b["newAccounts"]); !slices.Equal(got, []string{aliParent, saraParent}) || len(b["testers"].([]any)) != 1 {
		t.Fatalf("after removing: new %v, testers %v", got, b["testers"])
	}
	_ = ali

	// every change is in the audit log
	actions := map[string]bool{}
	for _, it := range adm.json("GET", "/audit", nil, 200)["items"].([]any) {
		actions[it.(map[string]any)["action"].(string)] = true
	}
	for _, x := range []string{"closed_test.settings", "closed_test.testers_added", "closed_test.account_linked", "closed_test.tester_removed", "closed_test.account_unlinked"} {
		if !actions[x] {
			t.Errorf("audit log misses %s", x)
		}
	}
}
