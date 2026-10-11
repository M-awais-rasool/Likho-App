package play

import (
	"context"
	"strings"
	"sync"
	"time"
)

// Fake is Google Play in memory, for tests: put purchases in Subs.
type Fake struct {
	mu    sync.Mutex
	Subs  map[string]Subscription // by purchase token
	Acked []string                // tokens acknowledged, in order
	Down  bool                    // Google cannot be reached
}

func NewFake() *Fake { return &Fake{Subs: map[string]Subscription{}} }

func (f *Fake) Set(token string, s Subscription) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.Subs[token] = s
}

func (f *Fake) Subscription(_ context.Context, token string) (Subscription, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.Down {
		return Subscription{}, errDown
	}
	s, ok := f.Subs[token]
	if !ok {
		return Subscription{}, ErrNotFound
	}
	return s, nil
}

func (f *Fake) Acknowledge(_ context.Context, _, token string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.Down {
		return errDown
	}
	s, ok := f.Subs[token]
	if !ok {
		return ErrNotFound
	}
	s.Acknowledged = true
	f.Subs[token] = s
	f.Acked = append(f.Acked, token)
	return nil
}

var errDown = &downError{}

type downError struct{}

func (*downError) Error() string { return "play: unreachable (fake)" }

// Dev is a development stand-in when no service account is set up:
// "dev:<basePlan>" tokens (e.g. dev:monthly, dev:yearly) are active
// subscriptions of [product] for 30 or 365 days from their first look-up.
type Dev struct {
	Product string

	mu   sync.Mutex
	seen map[string]Subscription
}

func (d *Dev) Subscription(_ context.Context, token string) (Subscription, error) {
	plan, ok := strings.CutPrefix(token, "dev:")
	if !ok || plan == "" {
		return Subscription{}, ErrNotFound
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.seen == nil {
		d.seen = map[string]Subscription{}
	}
	if s, ok := d.seen[token]; ok {
		return s, nil
	}
	days := 30
	if plan == "yearly" {
		days = 365
	}
	s := Subscription{State: StateActive, ProductID: d.Product, BasePlanID: plan, Expiry: time.Now().Add(time.Duration(days) * 24 * time.Hour), AutoRenewing: true, Test: true}
	d.seen[token] = s
	return s, nil
}

func (d *Dev) Acknowledge(context.Context, string, string) error { return nil }
