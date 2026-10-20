package repository

import (
	"context"
	"encoding/json"
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
		Updates(map[string]any{"plus_until": until, "trial_used": true, "trial_ends_at": until})
	if res.Error != nil {
		return model.Subscription{}, res.Error
	}
	if res.RowsAffected == 0 {
		if _, err := r.Get(ctx, parentID); err != nil {
			return model.Subscription{}, err
		}
		return model.Subscription{}, domain.ErrTrialUsed
	}
	return model.Subscription{Active: true, PlusUntil: p.PlusUntil, TrialUsed: true, Trial: true}, nil
}

// Features are the family's own switches (App controls), key -> on/off.
func (r *AccountRepository) Features(ctx context.Context, parentID string) (map[string]bool, error) {
	var p model.Parent
	if err := r.db.WithContext(ctx).Select("features").Take(&p, "id = ?", parentID).Error; err != nil {
		return nil, notFound(err)
	}
	out := map[string]bool{}
	if len(p.Features) > 0 {
		if err := json.Unmarshal(p.Features, &out); err != nil {
			return map[string]bool{}, nil // a broken value counts as none
		}
	}
	return out, nil
}

// SetFeatures replaces the family's own switches.
func (r *AccountRepository) SetFeatures(ctx context.Context, parentID string, f map[string]bool) error {
	res := r.db.WithContext(ctx).Model(&model.Parent{}).Where("id = ?", parentID).Update("features", model.JSONOf(f))
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
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

// SetPlusUntil sets when Likho Plus ends (admin panel: grant or revoke).
func (r *AccountRepository) SetPlusUntil(ctx context.Context, parentID string, until *time.Time) error {
	res := r.db.WithContext(ctx).Model(&model.Parent{}).Where("id = ?", parentID).Update("plus_until", until)
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
}

// GiveFullAccess gives Likho Plus until [until] (when it ends sooner) and
// opens every level (review accounts). True when anything changed.
func (r *AccountRepository) GiveFullAccess(ctx context.Context, parentID string, until time.Time) (bool, error) {
	res := r.db.WithContext(ctx).Model(&model.Parent{}).
		Where("id = ? AND (NOT tester OR plus_until IS NULL OR plus_until < ?)", parentID, until).
		Updates(map[string]any{"tester": true, "plus_until": gorm.Expr("GREATEST(COALESCE(plus_until, ?), ?)", until, until)})
	return res.RowsAffected > 0, res.Error
}

// FeatureCount is how many families have their own switch [Key] set to
// [On].
type FeatureCount struct {
	Key   string `json:"key"`
	On    bool   `json:"on"`
	Count int64  `json:"count"`
}

// FeatureCounts counts the families' own switches.
func (r *AccountRepository) FeatureCounts(ctx context.Context) ([]FeatureCount, error) {
	var out []FeatureCount
	err := r.db.WithContext(ctx).Raw(`SELECT f.key, f.value = 'true'::jsonb AS "on", count(*) AS count
		FROM parents p, jsonb_each(p.features) f GROUP BY 1, 2 ORDER BY 1, 2`).Scan(&out).Error
	return out, err
}
