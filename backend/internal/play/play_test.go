package play

import (
	"context"
	"encoding/base64"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// A SubscriptionPurchaseV2 as Google sends it (purchases.subscriptionsv2.get).
const v2 = `{
  "kind": "androidpublisher#subscriptionPurchaseV2",
  "regionCode": "PK",
  "startTime": "2026-10-11T10:00:00.120Z",
  "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
  "latestOrderId": "GPA.3300-1111-2222-33333",
  "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
  "externalAccountIdentifiers": {"obfuscatedExternalAccountId": "abc123"},
  "testPurchase": {},
  "lineItems": [{
    "productId": "likho_plus",
    "expiryTime": "2026-10-18T10:00:00.120Z",
    "autoRenewingPlan": {"autoRenewEnabled": true},
    "offerDetails": {"basePlanId": "yearly", "offerId": "free-trial-7d"}
  }]
}`

func TestClient(t *testing.T) {
	var acked string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == "GET" && r.URL.Path == "/androidpublisher/v3/applications/com.likho.abcwriting/purchases/subscriptionsv2/tokens/tok.1-a":
			io.WriteString(w, v2)
		case r.Method == "POST" && r.URL.Path == "/androidpublisher/v3/applications/com.likho.abcwriting/purchases/subscriptions/likho_plus/tokens/tok.1-a:acknowledge":
			acked = r.URL.Path
			w.WriteHeader(204)
		case strings.Contains(r.URL.Path, "/tokens/broken"):
			w.WriteHeader(500)
		default:
			w.WriteHeader(404)
			io.WriteString(w, `{"error":{"code":404,"message":"The purchase token was not found."}}`)
		}
	}))
	defer srv.Close()
	c := &Client{BaseURL: srv.URL, Package: "com.likho.abcwriting", HTTP: srv.Client()}
	ctx := context.Background()

	s, err := c.Subscription(ctx, "tok.1-a")
	if err != nil {
		t.Fatal(err)
	}
	want := Subscription{State: StateActive, ProductID: "likho_plus", BasePlanID: "yearly", OfferID: "free-trial-7d",
		Expiry: time.Date(2026, 10, 18, 10, 0, 0, 120e6, time.UTC), AutoRenewing: true, AccountID: "abc123",
		OrderID: "GPA.3300-1111-2222-33333", Test: true}
	if !s.Expiry.Equal(want.Expiry) {
		t.Fatalf("expiry %v", s.Expiry)
	}
	s.Expiry = want.Expiry
	if s != want {
		t.Fatalf("got %+v\nwant %+v", s, want)
	}
	if !s.Entitled(time.Date(2026, 10, 12, 0, 0, 0, 0, time.UTC)) || s.Entitled(time.Date(2026, 10, 19, 0, 0, 0, 0, time.UTC)) {
		t.Error("entitled until the expiry only")
	}
	if err := c.Acknowledge(ctx, "likho_plus", "tok.1-a"); err != nil || acked == "" {
		t.Fatalf("acknowledge: %v %q", err, acked)
	}
	if _, err := c.Subscription(ctx, "nope"); !errors.Is(err, ErrNotFound) {
		t.Errorf("unknown token: %v", err)
	}
	if _, err := c.Subscription(ctx, "broken"); err == nil || errors.Is(err, ErrNotFound) {
		t.Errorf("server error: %v", err)
	}
}

func TestStates(t *testing.T) {
	now := time.Now()
	later := now.Add(time.Hour)
	for state, want := range map[string]bool{
		StateActive: true, StateCanceled: true, StateInGrace: true,
		StateOnHold: false, StatePaused: false, StateExpired: false, StatePending: false, StatePendingCanceled: false,
	} {
		if got := (Subscription{State: state, Expiry: later}).Entitled(now); got != want {
			t.Errorf("%s: %v", state, got)
		}
	}
}

func push(data string) []byte {
	return []byte(`{"message":{"data":"` + base64.StdEncoding.EncodeToString([]byte(data)) + `","messageId":"1"},"subscription":"projects/p/subscriptions/s"}`)
}

func TestParsePush(t *testing.T) {
	n, err := ParsePush(push(`{"version":"1.0","packageName":"com.likho.abcwriting","eventTimeMillis":"1","subscriptionNotification":{"version":"1.0","notificationType":2,"purchaseToken":"tok","subscriptionId":"likho_plus"}}`))
	if err != nil || n != (Notification{PackageName: "com.likho.abcwriting", Token: "tok", Type: 2}) {
		t.Fatalf("renewal: %+v %v", n, err)
	}
	n, err = ParsePush(push(`{"packageName":"com.likho.abcwriting","voidedPurchaseNotification":{"purchaseToken":"tok","orderId":"GPA.1","productType":1,"refundType":1}}`))
	if err != nil || !n.Voided || n.Token != "tok" {
		t.Fatalf("voided: %+v %v", n, err)
	}
	n, err = ParsePush(push(`{"packageName":"com.likho.abcwriting","testNotification":{"version":"1.0"}}`))
	if err != nil || !n.Test || n.Token != "" {
		t.Fatalf("test: %+v %v", n, err)
	}
	for _, bad := range [][]byte{[]byte(`nope`), []byte(`{"message":{}}`), []byte(`{"message":{"data":"%%%"}}`), push(`not json`)} {
		if _, err := ParsePush(bad); err == nil {
			t.Errorf("accepted %s", bad)
		}
	}
}

func TestDev(t *testing.T) {
	d := &Dev{Product: "likho_plus"}
	s, err := d.Subscription(context.Background(), "dev:yearly")
	if err != nil || s.BasePlanID != "yearly" || !s.Entitled(time.Now().Add(300*24*time.Hour)) {
		t.Fatalf("%+v %v", s, err)
	}
	if again, _ := d.Subscription(context.Background(), "dev:yearly"); !again.Expiry.Equal(s.Expiry) {
		t.Error("the same token, the same purchase")
	}
	if _, err := d.Subscription(context.Background(), "real-token"); !errors.Is(err, ErrNotFound) {
		t.Error("only dev: tokens")
	}
}
