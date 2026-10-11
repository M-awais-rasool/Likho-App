package e2e

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	"likho/backend/internal/app"
	"likho/backend/internal/domain"
	"likho/backend/internal/play"
)

// pushBody is a Pub/Sub push of a Google Play developer notification.
func pushBody(data string) []byte {
	return []byte(`{"message":{"data":"` + base64.StdEncoding.EncodeToString([]byte(data)) + `","messageId":"1"},"subscription":"projects/likho/subscriptions/play"}`)
}

func renewal(token string, kind int) []byte {
	return pushBody(fmt.Sprintf(`{"version":"1.0","packageName":"com.likho.abcwriting","eventTimeMillis":"1","subscriptionNotification":{"version":"1.0","notificationType":%d,"purchaseToken":%q,"subscriptionId":"likho_plus"}}`, kind, token))
}

func TestPlayBillingNotSetUp(t *testing.T) {
	a := newTestApp(t)
	tok, _, _ := a.signIn("ammi@gmail.com")
	want(t, a.do("POST", "/v1/me/purchases/google", tok, map[string]any{"productId": "likho_plus", "purchaseToken": "dev:monthly"}), http.StatusServiceUnavailable, "store_unavailable")
}

// Likho Plus bought in Google Play: the token is checked at Google, belongs
// to one account, gives Plus to its expiry; notifications renew, cancel
// and refund it; a refund never takes away a longer grant.
func TestPlayBilling(t *testing.T) {
	g := play.NewFake()
	a := newTestAppWith(t, func(d *app.Deps) { d.Play, d.PlayNotifyKey = g, "push-key" })
	adm := a.admin()
	now := time.Now()
	signIn := func(email string) (tok, id string, sub map[string]any) {
		t.Helper()
		r := a.do("POST", "/v1/auth/google", "", map[string]any{"idToken": "dev:" + email})
		me := r.json()["me"].(map[string]any)
		return r.json()["accessToken"].(string), me["account"].(map[string]any)["id"].(string), me["subscription"].(map[string]any)
	}
	sub := func(tok string) map[string]any {
		t.Helper()
		return a.do("GET", "/v1/me", tok, nil).json()["subscription"].(map[string]any)
	}
	verify := func(tok, token string) res {
		t.Helper()
		return a.do("POST", "/v1/me/purchases/google", tok, map[string]any{"productId": "likho_plus", "purchaseToken": token})
	}
	notify := func(body []byte, key string) res {
		t.Helper()
		return a.do("POST", "/v1/play/notifications?key="+key, "", json.RawMessage(body))
	}
	monthly := func(account string, days int) play.Subscription {
		return play.Subscription{State: play.StateActive, ProductID: "likho_plus", BasePlanID: "monthly", Expiry: now.Add(time.Duration(days) * 24 * time.Hour),
			AutoRenewing: true, AccountID: domain.StoreAccountID(account), OrderID: "GPA.1"}
	}

	tokA, idA, s := signIn("ammi@gmail.com")
	if s["active"] != false || s["storeAccountId"] != domain.StoreAccountID(idA) {
		t.Fatalf("before buying: %v", s)
	}

	// bought in the app: Plus, the plan, acknowledged
	g.Set("tok-a", monthly(idA, 30))
	r := verify(tokA, "tok-a")
	want(t, r, 200)
	s = r.json()["subscription"].(map[string]any)
	if s["active"] != true || s["store"] != "google_play" || s["plan"] != "monthly" || s["autoRenewing"] != true {
		t.Fatalf("after buying: %v", s)
	}
	if len(g.Acked) != 1 || g.Acked[0] != "tok-a" {
		t.Fatalf("acknowledged: %v", g.Acked)
	}
	want(t, verify(tokA, "tok-a"), 200) // sent again (restore): fine
	if len(g.Acked) != 1 {
		t.Fatal("acknowledged once")
	}

	// the same purchase cannot give Plus to another account
	tokB, idB, _ := signIn("abbu@gmail.com")
	want(t, verify(tokB, "tok-a"), http.StatusConflict, "purchase_other_account")
	g.Set("tok-b", monthly(idB, 30)) // bought for B, sent by A
	want(t, verify(tokA, "tok-b"), http.StatusConflict, "purchase_other_account")
	want(t, verify(tokB, "tok-b"), 200)

	// what Google does not know, another product, an unfinished payment, Google down
	want(t, verify(tokA, "made-up-token"), http.StatusBadRequest, "purchase_invalid")
	other := monthly(idA, 30)
	other.ProductID = "coins"
	g.Set("tok-coins", other)
	want(t, verify(tokA, "tok-coins"), http.StatusBadRequest, "purchase_invalid")
	pending := monthly(idA, 30)
	pending.State = play.StatePending
	g.Set("tok-pending", pending)
	want(t, verify(tokA, "tok-pending"), http.StatusConflict, "purchase_pending")
	want(t, a.do("POST", "/v1/me/purchases/google", tokA, map[string]any{"purchaseToken": "bad token!"}), http.StatusBadRequest, "purchase_invalid")
	g.Down = true
	want(t, verify(tokA, "tok-a"), http.StatusServiceUnavailable, "store_unreachable")
	g.Down = false

	// notifications: only with the push URL's key
	want(t, notify(renewal("tok-a", 2), "wrong"), http.StatusForbidden)
	want(t, notify(pushBody(`{"packageName":"com.likho.abcwriting","testNotification":{"version":"1.0"}}`), "push-key"), http.StatusNoContent)
	want(t, notify([]byte(`not a push`), "push-key"), http.StatusNoContent)

	// renewed: Plus runs to the new expiry
	g.Set("tok-a", monthly(idA, 60))
	want(t, notify(renewal("tok-a", 2), "push-key"), http.StatusNoContent)
	if until, _ := time.Parse(time.RFC3339Nano, sub(tokA)["plusUntil"].(string)); until.Before(now.Add(59 * 24 * time.Hour)) {
		t.Fatalf("renewed until %v", until)
	}

	// cancelled: still Plus until the end, but it will not renew
	canceled := monthly(idA, 60)
	canceled.State, canceled.AutoRenewing = play.StateCanceled, false
	g.Set("tok-a", canceled)
	want(t, notify(renewal("tok-a", 3), "push-key"), http.StatusNoContent)
	if s := sub(tokA); s["active"] != true || s["autoRenewing"] != false {
		t.Fatalf("cancelled: %v", s)
	}

	// refunded (revoked): Plus ends now
	revoked := monthly(idA, 0)
	revoked.State, revoked.Expiry = play.StateExpired, now.Add(-time.Minute)
	g.Set("tok-a", revoked)
	want(t, notify(pushBody(`{"packageName":"com.likho.abcwriting","voidedPurchaseNotification":{"purchaseToken":"tok-a","orderId":"GPA.1","productType":1,"refundType":1}}`), "push-key"), http.StatusNoContent)
	if s := sub(tokA); s["active"] != false || s["store"] != nil {
		t.Fatalf("refunded: %v", s)
	}

	// a longer grant from the team survives a refund
	tokC, idC, _ := signIn("nani@gmail.com")
	adm.json("POST", "/families/"+idC+"/plus", map[string]any{"days": 365}, 200)
	g.Set("tok-c", monthly(idC, 30))
	want(t, verify(tokC, "tok-c"), 200)
	revokedC := monthly(idC, 0)
	revokedC.State, revokedC.Expiry = play.StateExpired, now.Add(-time.Minute)
	g.Set("tok-c", revokedC)
	want(t, notify(renewal("tok-c", 12), "push-key"), http.StatusNoContent)
	if s := sub(tokC); s["active"] != true {
		t.Fatalf("grant lost: %v", s)
	}

	// a purchase the app never sent (closed too soon): the notification links it to the account it was bought for
	tokD, idD, _ := signIn("dada@gmail.com")
	g.Set("tok-d", monthly(idD, 30))
	want(t, notify(renewal("tok-d", 4), "push-key"), http.StatusNoContent)
	if s := sub(tokD); s["active"] != true {
		t.Fatalf("linked by notification: %v", s)
	}
	g.Set("tok-nobody", monthly("00000000-0000-0000-0000-000000000000", 30))
	want(t, notify(renewal("tok-nobody", 4), "push-key"), http.StatusNoContent)

	// the admin panel shows the purchases
	fam := adm.json("GET", "/families/"+idD, nil, 200)
	if ps := fam["purchases"].([]any); len(ps) != 1 || ps[0].(map[string]any)["plan"] != "monthly" {
		t.Fatalf("admin purchases: %v", fam["purchases"])
	}

	// an account deleted while subscribed: a new account can restore the purchase
	want(t, a.do("DELETE", "/v1/me", tokD, nil), http.StatusNoContent)
	tokE, _, _ := signIn("dada.new@gmail.com")
	want(t, verify(tokE, "tok-d"), 200)
}
