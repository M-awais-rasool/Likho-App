package service

import (
	"context"
	"crypto/subtle"
	"errors"
	"log/slog"
	"regexp"
	"time"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/play"
	"likho/backend/internal/repository"
)

// BillingService: Likho Plus bought in Google Play. The app sends the
// purchase token after a purchase (or a restore); Google's real-time
// developer notifications report renewals, cancellations and refunds.
// Either way the token is looked up at Google (the app's word is never
// trusted), it belongs to one account only, and that account's Plus runs
// at least to the purchase's expiry. A purchase that ends early (refund,
// revoke) ends the Plus it gave, but never a trial or a grant that lasts
// longer.
type BillingService struct {
	api       play.API // nil: purchases are not set up on this server
	repo      *repository.PlayRepository
	accounts  *repository.AccountRepository
	cache     *cache.Cache
	activity  *ActivityService
	pkg       string // the app's package name
	product   string // the Likho Plus subscription's product ID
	notifyKey string // the secret in the notification push URL ("" = none)
	now       func() time.Time
}

func NewBillingService(api play.API, repo *repository.PlayRepository, accounts *repository.AccountRepository, c *cache.Cache, activity *ActivityService, packageName, product, notifyKey string) *BillingService {
	return &BillingService{api: api, repo: repo, accounts: accounts, cache: c, activity: activity, pkg: packageName, product: product, notifyKey: notifyKey, now: time.Now}
}

var purchaseTokenRe = regexp.MustCompile(`^[A-Za-z0-9._:\-]+$`)

func validToken(t string) bool {
	return len(t) >= 4 && len(t) <= 4096 && purchaseTokenRe.MatchString(t)
}

// VerifyGoogle checks a purchase the app made or restored, links it to the
// account and gives its Plus. It answers the account's subscription.
func (s *BillingService) VerifyGoogle(ctx context.Context, parentID, productID, token string) (model.Subscription, error) {
	if s.api == nil {
		return model.Subscription{}, domain.ErrStoreUnavailable
	}
	if !validToken(token) || (productID != "" && productID != s.product) {
		return model.Subscription{}, domain.ErrPurchaseInvalid
	}
	sub, err := s.lookUp(ctx, token)
	if err != nil {
		return model.Subscription{}, err
	}
	if sub.ProductID != s.product {
		return model.Subscription{}, domain.ErrPurchaseInvalid
	}
	if sub.State == play.StatePending {
		return model.Subscription{}, domain.ErrPurchasePending
	}
	owner, err := s.owner(ctx, token, sub)
	if err != nil {
		return model.Subscription{}, err
	}
	if owner != "" && owner != parentID {
		return model.Subscription{}, domain.ErrPurchaseOtherAccount
	}
	if err := s.apply(ctx, parentID, token, sub); err != nil {
		return model.Subscription{}, err
	}
	p, err := s.accounts.Get(ctx, parentID)
	if err != nil {
		return model.Subscription{}, err
	}
	return s.Subscription(ctx, p)
}

// Notify handles a real-time developer notification (Pub/Sub push) with
// the push URL's [key]. Errors make Pub/Sub send it again later.
func (s *BillingService) Notify(ctx context.Context, key string, body []byte) error {
	if s.notifyKey != "" && subtle.ConstantTimeCompare([]byte(key), []byte(s.notifyKey)) != 1 {
		return domain.ErrAdminForbidden
	}
	n, err := play.ParsePush(body)
	if err != nil {
		slog.Warn("play notification: ignored", "err", err)
		return nil // sending it again would not help
	}
	if n.Test || n.Token == "" {
		slog.Info("play notification: test", "package", n.PackageName)
		return nil
	}
	if n.PackageName != "" && n.PackageName != s.pkg {
		slog.Warn("play notification: another app", "package", n.PackageName)
		return nil
	}
	if s.api == nil {
		return domain.ErrStoreUnavailable
	}
	sub, err := s.lookUp(ctx, n.Token)
	if errors.Is(err, domain.ErrPurchaseInvalid) {
		slog.Warn("play notification: unknown purchase", "type", n.Type, "voided", n.Voided)
		return nil
	}
	if err != nil {
		return err
	}
	if sub.ProductID != s.product {
		return nil
	}
	owner, err := s.owner(ctx, n.Token, sub)
	if err != nil {
		return err
	}
	if owner == "" {
		// bought by an account that no longer exists, or not sent by the
		// app yet (it will be, with the account it was bought for)
		slog.Info("play notification: purchase of no account", "type", n.Type, "state", sub.State)
		return nil
	}
	return s.apply(ctx, owner, n.Token, sub)
}

// Subscription is the account's Likho Plus as the API shows it, with the
// Google Play subscription behind it, if any.
func (s *BillingService) Subscription(ctx context.Context, p model.Parent) (model.Subscription, error) {
	return subscriptionOf(ctx, s.repo, p, s.now())
}

func subscriptionOf(ctx context.Context, repo *repository.PlayRepository, p model.Parent, now time.Time) (model.Subscription, error) {
	out := p.Subscription(now)
	rows, err := repo.ForParent(ctx, p.ID)
	if err != nil {
		return out, err
	}
	for _, r := range rows {
		if (play.Subscription{State: r.State, Expiry: r.ExpiresAt}).Entitled(now) {
			out.Store, out.Plan, out.AutoRenewing = "google_play", r.BasePlanID, r.AutoRenewing
			break
		}
	}
	return out, nil
}

// lookUp asks Google about the token.
func (s *BillingService) lookUp(ctx context.Context, token string) (play.Subscription, error) {
	sub, err := s.api.Subscription(ctx, token)
	if errors.Is(err, play.ErrNotFound) {
		slog.Info("play: purchase not found", "err", err)
		return sub, domain.ErrPurchaseInvalid
	}
	if err != nil {
		slog.Error("play: look-up failed", "err", err)
		return sub, domain.ErrStoreUnreachable
	}
	return sub, nil
}

// owner is the account the purchase belongs to: the one it was linked to,
// or else the account it was bought for (its StoreAccountID). "" = none.
func (s *BillingService) owner(ctx context.Context, token string, sub play.Subscription) (string, error) {
	row, found, err := s.repo.Get(ctx, token)
	if err != nil || found {
		return row.ParentID, err
	}
	if sub.AccountID == "" {
		return "", nil
	}
	id, _, err := s.repo.ParentByAccountHash(ctx, sub.AccountID)
	return id, err
}

// apply saves what Google said about the purchase and moves the
// account's Plus with it; then it acknowledges a new purchase.
func (s *BillingService) apply(ctx context.Context, parentID, token string, sub play.Subscription) error {
	prev, found, err := s.repo.Get(ctx, token)
	if err != nil {
		return err
	}
	now := s.now()
	row := model.PlaySubscription{
		PurchaseToken: token, ParentID: parentID, ProductID: sub.ProductID, BasePlanID: sub.BasePlanID, OfferID: sub.OfferID,
		State: sub.State, ExpiresAt: sub.Expiry.UTC().Truncate(time.Microsecond), AutoRenewing: sub.AutoRenewing,
		Acknowledged: sub.Acknowledged, OrderID: sub.OrderID, LinkedToken: sub.LinkedToken, Test: sub.Test,
	}
	switch {
	case sub.Entitled(now):
		if _, err := s.repo.ExtendPlus(ctx, parentID, row.ExpiresAt); err != nil {
			return err
		}
	case found && prev.ExpiresAt.After(now):
		// ended early (refund, revoke, on hold): end the Plus it gave
		to := row.ExpiresAt
		if to.After(now) {
			to = now
		}
		if _, err := s.repo.EndPlusFrom(ctx, parentID, prev.ExpiresAt, to); err != nil {
			return err
		}
	}
	if sub.Entitled(now) && !sub.Acknowledged {
		if err := s.api.Acknowledge(ctx, sub.ProductID, token); err != nil {
			// the app acknowledges too, and the next notification retries
			slog.Warn("play: acknowledge failed", "err", err)
		} else {
			row.Acknowledged = true
		}
	}
	if err := s.repo.Save(ctx, &row); err != nil {
		return err
	}
	s.cache.ForgetMe(ctx, parentID)
	if !found && sub.Entitled(now) && s.activity != nil {
		s.activity.Event(ctx, model.ActivityEvent{Type: model.EventPlusPurchased, ParentID: &parentID,
			Detail: model.JSONOf(map[string]any{"plan": sub.BasePlanID, "offer": sub.OfferID, "test": sub.Test})})
	}
	return nil
}
