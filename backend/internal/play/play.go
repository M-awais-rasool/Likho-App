// Package play talks to the Google Play Developer API about Likho Plus
// subscriptions: what state a purchase is in (purchases.subscriptionsv2),
// acknowledging it, and the real-time developer notifications Google sends
// through Pub/Sub when a subscription changes. The app's word is never
// trusted: every purchase token is looked up at Google.
package play

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"golang.org/x/oauth2/google"
)

// Subscription states (SubscriptionPurchaseV2.subscriptionState).
const (
	StateActive          = "SUBSCRIPTION_STATE_ACTIVE"
	StateCanceled        = "SUBSCRIPTION_STATE_CANCELED" // will not renew: Plus until it expires
	StateInGrace         = "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
	StateOnHold          = "SUBSCRIPTION_STATE_ON_HOLD"
	StatePaused          = "SUBSCRIPTION_STATE_PAUSED"
	StateExpired         = "SUBSCRIPTION_STATE_EXPIRED"
	StatePending         = "SUBSCRIPTION_STATE_PENDING" // the payment is not finished yet
	StatePendingCanceled = "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED"
)

// Subscription is one purchase token as Google reports it.
type Subscription struct {
	State        string
	ProductID    string
	BasePlanID   string // e.g. "monthly", "yearly"
	OfferID      string // e.g. the free trial offer
	Expiry       time.Time
	AutoRenewing bool
	Acknowledged bool
	AccountID    string // obfuscatedExternalAccountId the app set when buying
	LinkedToken  string // the purchase this one replaced (resubscribe, plan change)
	OrderID      string
	Test         bool // a license tester's purchase (no money moved)
}

// Entitled says whether the purchase gives Likho Plus at [now].
func (s Subscription) Entitled(now time.Time) bool {
	switch s.State {
	case StateActive, StateCanceled, StateInGrace:
		return s.Expiry.After(now)
	}
	return false
}

// ErrNotFound: Google does not know the token (or it is too old).
var ErrNotFound = errors.New("play: purchase not found")

// API is what Likho asks Google Play.
type API interface {
	Subscription(ctx context.Context, token string) (Subscription, error)
	Acknowledge(ctx context.Context, productID, token string) error
}

const scope = "https://www.googleapis.com/auth/androidpublisher"

// Client is the real Google Play Developer API, signed in as a service
// account that has access to the app in Play Console.
type Client struct {
	BaseURL string // default https://androidpublisher.googleapis.com
	Package string // the app's package name
	HTTP    *http.Client
}

// NewClient signs in with the service account's JSON key.
func NewClient(ctx context.Context, packageName string, serviceAccountJSON []byte) (*Client, error) {
	conf, err := google.JWTConfigFromJSON(serviceAccountJSON, scope)
	if err != nil {
		return nil, fmt.Errorf("play: service account key: %w", err)
	}
	hc := conf.Client(context.WithoutCancel(ctx))
	hc.Timeout = 15 * time.Second
	return &Client{Package: packageName, HTTP: hc}, nil
}

func (c *Client) url(format string, args ...any) string {
	base := c.BaseURL
	if base == "" {
		base = "https://androidpublisher.googleapis.com"
	}
	return strings.TrimRight(base, "/") + "/androidpublisher/v3/applications/" + url.PathEscape(c.Package) + fmt.Sprintf(format, args...)
}

// subscriptionV2 is the part of SubscriptionPurchaseV2 Likho reads.
type subscriptionV2 struct {
	SubscriptionState    string    `json:"subscriptionState"`
	AcknowledgementState string    `json:"acknowledgementState"`
	LatestOrderID        string    `json:"latestOrderId"`
	LinkedPurchaseToken  string    `json:"linkedPurchaseToken"`
	TestPurchase         *struct{} `json:"testPurchase"`
	ExternalAccountIDs   *struct {
		ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	} `json:"externalAccountIdentifiers"`
	LineItems []struct {
		ProductID        string `json:"productId"`
		ExpiryTime       string `json:"expiryTime"`
		AutoRenewingPlan *struct {
			AutoRenewEnabled bool `json:"autoRenewEnabled"`
		} `json:"autoRenewingPlan"`
		OfferDetails *struct {
			BasePlanID string `json:"basePlanId"`
			OfferID    string `json:"offerId"`
		} `json:"offerDetails"`
	} `json:"lineItems"`
}

// Subscription looks the purchase token up (purchases.subscriptionsv2.get).
func (c *Client) Subscription(ctx context.Context, token string) (Subscription, error) {
	body, err := c.do(ctx, http.MethodGet, c.url("/purchases/subscriptionsv2/tokens/%s", url.PathEscape(token)), nil)
	if err != nil {
		return Subscription{}, err
	}
	var v subscriptionV2
	if err := json.Unmarshal(body, &v); err != nil {
		return Subscription{}, fmt.Errorf("play: subscription: %w", err)
	}
	return v.subscription(), nil
}

func (v subscriptionV2) subscription() Subscription {
	s := Subscription{
		State:        v.SubscriptionState,
		Acknowledged: v.AcknowledgementState == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
		OrderID:      v.LatestOrderID,
		LinkedToken:  v.LinkedPurchaseToken,
		Test:         v.TestPurchase != nil,
	}
	if v.ExternalAccountIDs != nil {
		s.AccountID = v.ExternalAccountIDs.ObfuscatedExternalAccountID
	}
	// one line item per product; Likho sells one, the latest expiry wins
	for _, li := range v.LineItems {
		exp, err := time.Parse(time.RFC3339Nano, li.ExpiryTime)
		if err != nil || (!s.Expiry.IsZero() && !exp.After(s.Expiry)) {
			continue
		}
		s.Expiry, s.ProductID = exp, li.ProductID
		s.AutoRenewing = li.AutoRenewingPlan != nil && li.AutoRenewingPlan.AutoRenewEnabled
		s.BasePlanID, s.OfferID = "", ""
		if li.OfferDetails != nil {
			s.BasePlanID, s.OfferID = li.OfferDetails.BasePlanID, li.OfferDetails.OfferID
		}
	}
	return s
}

// Acknowledge confirms the purchase to Google (unacknowledged purchases are
// refunded after three days).
func (c *Client) Acknowledge(ctx context.Context, productID, token string) error {
	_, err := c.do(ctx, http.MethodPost, c.url("/purchases/subscriptions/%s/tokens/%s:acknowledge", url.PathEscape(productID), url.PathEscape(token)), []byte("{}"))
	return err
}

func (c *Client) do(ctx context.Context, method, u string, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, u, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("play: %w", err)
	}
	defer res.Body.Close()
	out, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return nil, fmt.Errorf("play: %w", err)
	}
	switch {
	case res.StatusCode == http.StatusNotFound || res.StatusCode == http.StatusGone || res.StatusCode == http.StatusBadRequest:
		return nil, fmt.Errorf("%w (%d %s)", ErrNotFound, res.StatusCode, strings.TrimSpace(string(out)))
	case res.StatusCode >= 300:
		return nil, fmt.Errorf("play: %s %s: %d %s", method, req.URL.Path, res.StatusCode, strings.TrimSpace(string(out)))
	}
	return out, nil
}

// ------------------------------------------------------------ notifications

// Notification is a real-time developer notification (Pub/Sub push).
// Only the token matters: the state is always looked up at Google.
type Notification struct {
	PackageName string
	Token       string
	Type        int  // SubscriptionNotification.notificationType (0 = none)
	Voided      bool // a refund or chargeback
	Test        bool // "Send test notification" in Play Console
}

// ParsePush reads Pub/Sub's push body.
func ParsePush(body []byte) (Notification, error) {
	var push struct {
		Message struct {
			Data string `json:"data"`
		} `json:"message"`
	}
	if err := json.Unmarshal(body, &push); err != nil || push.Message.Data == "" {
		return Notification{}, errors.New("play: not a Pub/Sub push")
	}
	data, err := base64.StdEncoding.DecodeString(push.Message.Data)
	if err != nil {
		return Notification{}, errors.New("play: message data is not base64")
	}
	var dn struct {
		PackageName string `json:"packageName"`
		Sub         *struct {
			Type  int    `json:"notificationType"`
			Token string `json:"purchaseToken"`
		} `json:"subscriptionNotification"`
		Voided *struct {
			Token string `json:"purchaseToken"`
		} `json:"voidedPurchaseNotification"`
		Test *struct{} `json:"testNotification"`
	}
	if err := json.Unmarshal(data, &dn); err != nil {
		return Notification{}, errors.New("play: message data is not a developer notification")
	}
	n := Notification{PackageName: dn.PackageName, Test: dn.Test != nil}
	switch {
	case dn.Sub != nil:
		n.Type, n.Token = dn.Sub.Type, dn.Sub.Token
	case dn.Voided != nil:
		n.Voided, n.Token = true, dn.Voided.Token
	}
	return n, nil
}
