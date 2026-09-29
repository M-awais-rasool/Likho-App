package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// AccountRepository: parents (accounts), their settings and subscription.
type AccountRepository struct {
	db *gorm.DB
}

// SignInWithGoogle finds the parent for this Google account, or creates it
// the first time: there is no separate sign-up. created = new account.
func (r *AccountRepository) SignInWithGoogle(ctx context.Context, g model.GoogleUser) (p model.Parent, created bool, err error) {
	db := r.db.WithContext(ctx)
	for range 2 {
		err = db.Where("google_sub = ?", g.Sub).Take(&p).Error
		if err == nil {
			// returning parent: keep the profile fresh
			updates := map[string]any{"email": g.Email, "picture_url": g.Picture, "last_login_at": time.Now()}
			if g.Name != "" {
				updates["name"] = g.Name
			}
			return p, false, db.Model(&p).Updates(updates).Error
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return p, false, err
		}

		p = model.Parent{GoogleSub: g.Sub, Email: g.Email, Name: g.Name, PictureURL: g.Picture}
		if err = db.Create(&p).Error; err == nil {
			// read back the defaults the database filled in (settings)
			return p, true, db.Take(&p, "id = ?", p.ID).Error
		}
		if !errors.Is(err, gorm.ErrDuplicatedKey) {
			return p, false, err
		}
		// the same account signed in twice at once: the other request
		// created it, so read it on the next pass
	}
	return p, false, err
}

func (r *AccountRepository) Get(ctx context.Context, id string) (model.Parent, error) {
	var p model.Parent
	err := r.db.WithContext(ctx).Take(&p, "id = ?", id).Error
	return p, notFound(err)
}

// UpdateSettings changes the fields in [patch] (already validated).
func (r *AccountRepository) UpdateSettings(ctx context.Context, parentID string, patch model.SettingsPatch) (model.Settings, error) {
	updates := map[string]any{}
	set := func(col string, v any, ok bool) {
		if ok {
			updates[col] = v
		}
	}
	set("session_minutes", deref(patch.SessionMinutes), patch.SessionMinutes != nil)
	set("music", deref(patch.Music), patch.Music != nil)
	set("sfx", deref(patch.Sfx), patch.Sfx != nil)
	set("haptics", deref(patch.Haptics), patch.Haptics != nil)
	set("left_handed", deref(patch.LeftHanded), patch.LeftHanded != nil)
	set("reduce_motion", deref(patch.ReduceMotion), patch.ReduceMotion != nil)

	if len(updates) == 0 {
		p, err := r.Get(ctx, parentID)
		return p.Settings(), err
	}
	var p model.Parent
	res := r.db.WithContext(ctx).Model(&p).Clauses(clause.Returning{}).Where("id = ?", parentID).Updates(updates)
	if res.Error != nil {
		return model.Settings{}, res.Error
	}
	if res.RowsAffected == 0 {
		return model.Settings{}, domain.ErrNotFound
	}
	return p.Settings(), nil
}

// StartTrial gives Likho Plus for [days] days, once per account.
func (r *AccountRepository) StartTrial(ctx context.Context, parentID string, days int) (model.Subscription, error) {
	until := time.Now().Add(time.Duration(days) * 24 * time.Hour)
	var p model.Parent
	res := r.db.WithContext(ctx).Model(&p).Clauses(clause.Returning{}).
		Where("id = ? AND NOT trial_used", parentID).
		Updates(map[string]any{"plus_until": until, "trial_used": true})
	if res.Error != nil {
		return model.Subscription{}, res.Error
	}
	if res.RowsAffected == 0 {
		if _, err := r.Get(ctx, parentID); err != nil {
			return model.Subscription{}, err
		}
		return model.Subscription{}, domain.ErrTrialUsed
	}
	return model.Subscription{Active: true, PlusUntil: p.PlusUntil, TrialUsed: true}, nil
}

// Delete removes the parent and, by cascade, children, progress and
// sessions.
func (r *AccountRepository) Delete(ctx context.Context, parentID string) error {
	res := r.db.WithContext(ctx).Delete(&model.Parent{}, "id = ?", parentID)
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
}
