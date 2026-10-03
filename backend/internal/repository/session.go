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

// SessionRepository: signed-in devices (refresh tokens, stored hashed).
type SessionRepository struct {
	db *gorm.DB
}

// Create stores a new signed-in device (only the token's hash).
func (r *SessionRepository) Create(ctx context.Context, parentID string, tokenHash []byte, device string, expires time.Time) (string, error) {
	sess := model.Session{ParentID: parentID, TokenHash: tokenHash, Device: device, ExpiresAt: expires}
	err := r.db.WithContext(ctx).Create(&sess).Error
	return sess.ID, err
}

// Rotate swaps a refresh token for a new one (each refresh token
// works once). Presenting a token that was already swapped means it was
// copied: every session of that parent is revoked and domain.ErrSessionReused is
// returned. A token of a signed-out session is just invalid.
func (r *SessionRepository) Rotate(ctx context.Context, oldHash, newHash []byte, expires time.Time) (parentID, sessionID string, err error) {
	reusedBy := ""
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var old model.Session
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("token_hash = ?", oldHash).Take(&old).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return domain.ErrSessionInvalid
			}
			return err
		}
		now := time.Now()
		if old.RevokedAt != nil {
			if old.Rotated {
				reusedBy = old.ParentID // a used token came back: someone copied it
				return nil
			}
			return domain.ErrSessionInvalid // signed out
		}
		if old.ExpiresAt.Before(now) {
			return domain.ErrSessionInvalid
		}
		if err := tx.Model(&old).Updates(map[string]any{"revoked_at": now, "rotated": true}).Error; err != nil {
			return err
		}
		next := model.Session{ParentID: old.ParentID, TokenHash: newHash, Device: old.Device, ExpiresAt: expires}
		if err := tx.Create(&next).Error; err != nil {
			return err
		}
		parentID, sessionID = old.ParentID, next.ID
		return nil
	})
	if err == nil && reusedBy != "" {
		// done after the transaction above, so returning an error keeps it
		_ = r.RevokeAll(ctx, reusedBy)
		return "", "", domain.ErrSessionReused
	}
	return parentID, sessionID, err
}

// Revoke signs one device out.
func (r *SessionRepository) Revoke(ctx context.Context, parentID, sessionID string) error {
	return r.db.WithContext(ctx).Model(&model.Session{}).
		Where("id = ? AND parent_id = ? AND revoked_at IS NULL", sessionID, parentID).
		Update("revoked_at", time.Now()).Error
}

// RevokeAll signs every device of the parent out.
func (r *SessionRepository) RevokeAll(ctx context.Context, parentID string) error {
	return r.db.WithContext(ctx).Model(&model.Session{}).
		Where("parent_id = ? AND revoked_at IS NULL", parentID).
		Update("revoked_at", time.Now()).Error
}
