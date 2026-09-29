package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/game"
	"likho/backend/models"
)

// GoogleUser is what a verified Google ID token tells us.
type GoogleUser struct {
	Sub, Email, Name, Picture string
}

// SignInWithGoogle finds the parent for this Google account, or creates it
// the first time: there is no separate sign-up. created = new account.
func (s *Store) SignInWithGoogle(ctx context.Context, g GoogleUser) (p models.Parent, created bool, err error) {
	db := s.db.WithContext(ctx)
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

		p = models.Parent{GoogleSub: g.Sub, Email: g.Email, Name: g.Name, PictureURL: g.Picture}
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

func (s *Store) Parent(ctx context.Context, id string) (models.Parent, error) {
	var p models.Parent
	err := s.db.WithContext(ctx).Take(&p, "id = ?", id).Error
	return p, notFound(err)
}

// Me loads the whole account: parent, settings, subscription and every
// child with its progress.
func (s *Store) Me(ctx context.Context, parentID string) (models.Me, error) {
	p, err := s.Parent(ctx, parentID)
	if err != nil {
		return models.Me{}, err
	}
	kids, err := s.childViews(ctx, parentID, "")
	if err != nil {
		return models.Me{}, err
	}
	return models.Me{
		Account:      AccountOf(p),
		Settings:     SettingsOf(p),
		Subscription: models.Subscription{Active: p.PlusActive(time.Now()), PlusUntil: p.PlusUntil, TrialUsed: p.TrialUsed},
		Children:     kids,
	}, nil
}

func AccountOf(p models.Parent) models.Account {
	return models.Account{ID: p.ID, Email: p.Email, Name: p.Name, PictureURL: p.PictureURL}
}

func SettingsOf(p models.Parent) models.Settings {
	return models.Settings{
		SessionMinutes: p.SessionMinutes, Music: p.Music, Sfx: p.Sfx, Haptics: p.Haptics,
		LeftHanded: p.LeftHanded, ReduceMotion: p.ReduceMotion,
	}
}

// UpdateSettings changes the fields in [patch] (already validated).
func (s *Store) UpdateSettings(ctx context.Context, parentID string, patch models.SettingsPatch) (models.Settings, error) {
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

	var p models.Parent
	db := s.db.WithContext(ctx)
	if len(updates) > 0 {
		res := db.Model(&p).Clauses(clause.Returning{}).Where("id = ?", parentID).Updates(updates)
		if res.Error != nil {
			return models.Settings{}, res.Error
		}
		if res.RowsAffected == 0 {
			return models.Settings{}, ErrNotFound
		}
		return SettingsOf(p), nil
	}
	p, err := s.Parent(ctx, parentID)
	return SettingsOf(p), err
}

// StartTrial gives 7 days of Likho Plus, once per account.
func (s *Store) StartTrial(ctx context.Context, parentID string) (models.Subscription, error) {
	until := time.Now().Add(game.TrialDays * 24 * time.Hour)
	var p models.Parent
	res := s.db.WithContext(ctx).Model(&p).Clauses(clause.Returning{}).
		Where("id = ? AND NOT trial_used", parentID).
		Updates(map[string]any{"plus_until": until, "trial_used": true})
	if res.Error != nil {
		return models.Subscription{}, res.Error
	}
	if res.RowsAffected == 0 {
		if _, err := s.Parent(ctx, parentID); err != nil {
			return models.Subscription{}, err
		}
		return models.Subscription{}, ErrTrialUsed
	}
	return models.Subscription{Active: true, PlusUntil: p.PlusUntil, TrialUsed: true}, nil
}

// DeleteAccount removes the parent and, by cascade, children, progress and
// sessions.
func (s *Store) DeleteAccount(ctx context.Context, parentID string) error {
	res := s.db.WithContext(ctx).Delete(&models.Parent{}, "id = ?", parentID)
	if res.Error == nil && res.RowsAffected == 0 {
		return ErrNotFound
	}
	return res.Error
}

func deref[T any](p *T) T {
	if p == nil {
		var z T
		return z
	}
	return *p
}
