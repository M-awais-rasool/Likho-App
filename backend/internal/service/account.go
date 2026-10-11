package service

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// AccountService: the signed-in parent's account, settings and
// subscription, and /v1/me (everything the app needs, cached in Redis).
type AccountService struct {
	accounts *repository.AccountRepository
	children *repository.ChildRepository
	play     *repository.PlayRepository
	cache    *cache.Cache
	activity *ActivityService
}

func NewAccountService(accounts *repository.AccountRepository, children *repository.ChildRepository, playRepo *repository.PlayRepository, c *cache.Cache, activity *ActivityService) *AccountService {
	return &AccountService{accounts: accounts, children: children, play: playRepo, cache: c, activity: activity}
}

// Me loads the whole account: parent, settings, subscription and every
// child with their progress.
func (s *AccountService) Me(ctx context.Context, parentID string) (model.Me, error) {
	p, err := s.accounts.Get(ctx, parentID)
	if errors.Is(err, domain.ErrNotFound) {
		return model.Me{}, domain.ErrAccountDeleted
	}
	if err != nil {
		return model.Me{}, err
	}
	kids, err := s.children.Views(ctx, parentID)
	if err != nil {
		return model.Me{}, err
	}
	sub, err := subscriptionOf(ctx, s.play, p, time.Now())
	if err != nil {
		return model.Me{}, err
	}
	return model.Me{Account: p.Account(), Settings: p.Settings(), Subscription: sub, Children: kids}, nil
}

// MeJSON is Me as JSON, from the cache when possible (hit = it was).
func (s *AccountService) MeJSON(ctx context.Context, parentID string) (body []byte, hit bool, err error) {
	if body, ok := s.cache.Me(ctx, parentID); ok {
		return body, true, nil
	}
	me, err := s.Me(ctx, parentID)
	if err != nil {
		return nil, false, err
	}
	if body, err = json.Marshal(me); err != nil {
		return nil, false, err
	}
	s.cache.SetMe(ctx, parentID, body)
	return body, false, nil
}

// UpdateSettings changes only the fields that are sent.
func (s *AccountService) UpdateSettings(ctx context.Context, parentID string, patch model.SettingsPatch) (model.Settings, error) {
	if patch.SessionMinutes != nil && !domain.ValidSessionMinutes(*patch.SessionMinutes) {
		return model.Settings{}, domain.Invalid("sessionMinutes must be 5, 10 or 15")
	}
	out, err := s.accounts.UpdateSettings(ctx, parentID, patch)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
	}
	return out, err
}

// StartTrial gives 7 days of Likho Plus, once per account. Store purchases
// (App Store / Google Play) will extend plusUntil the same way.
func (s *AccountService) StartTrial(ctx context.Context, parentID string) (model.Subscription, error) {
	out, err := s.accounts.StartTrial(ctx, parentID, domain.TrialDays)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		s.activity.TrialStarted(ctx, parentID)
	}
	return out, err
}

// Delete removes the account and everything in it.
// Its events go with it; only an anonymous "account deleted" (with the
// country) is kept for the numbers.
func (s *AccountService) Delete(ctx context.Context, parentID string) error {
	p, _ := s.accounts.Get(ctx, parentID)
	err := s.accounts.Delete(ctx, parentID)
	s.cache.ForgetMe(ctx, parentID)
	if err == nil {
		s.activity.Event(ctx, model.ActivityEvent{Type: model.EventAccountDeleted,
			Detail: model.JSONOf(map[string]any{"country": p.Country, "platform": p.Platform})})
	}
	return err
}

// reviewPlusUntil: review accounts keep Likho Plus for good.
var reviewPlusUntil = time.Date(2099, 12, 31, 0, 0, 0, 0, time.UTC)

// GiveFullAccess gives the account Likho Plus and every level open (review
// accounts, at every sign-in).
func (s *AccountService) GiveFullAccess(ctx context.Context, parentID string) error {
	changed, err := s.accounts.GiveFullAccess(ctx, parentID, reviewPlusUntil)
	if changed {
		s.cache.ForgetMe(ctx, parentID)
	}
	return err
}
