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
	cache    *cache.Cache
}

func NewAccountService(accounts *repository.AccountRepository, children *repository.ChildRepository, c *cache.Cache) *AccountService {
	return &AccountService{accounts: accounts, children: children, cache: c}
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
	return model.Me{Account: p.Account(), Settings: p.Settings(), Subscription: p.Subscription(time.Now()), Children: kids}, nil
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
	}
	return out, err
}

// Delete removes the account and everything in it.
func (s *AccountService) Delete(ctx context.Context, parentID string) error {
	err := s.accounts.Delete(ctx, parentID)
	s.cache.ForgetMe(ctx, parentID)
	return err
}
