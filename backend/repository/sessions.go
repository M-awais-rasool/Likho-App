package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/models"
)

// CreateSession stores a new signed-in device (only the token's hash).
func (s *Store) CreateSession(ctx context.Context, parentID string, tokenHash []byte, device string, expires time.Time) (string, error) {
	sess := models.Session{ParentID: parentID, TokenHash: tokenHash, Device: device, ExpiresAt: expires}
	err := s.db.WithContext(ctx).Create(&sess).Error
	return sess.ID, err
}

// RotateSession swaps a refresh token for a new one (each refresh token
// works once). Presenting a token that was already swapped means it was
// copied: every session of that parent is revoked and ErrSessionReused is
// returned. A token of a signed-out session is just invalid.
func (s *Store) RotateSession(ctx context.Context, oldHash, newHash []byte, expires time.Time) (parentID, sessionID string, err error) {
	reusedBy := ""
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var old models.Session
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("token_hash = ?", oldHash).Take(&old).Error; err != nil {
			if notFound(err) == ErrNotFound {
				return ErrSessionInvalid
			}
			return err
		}
		now := time.Now()
		if old.RevokedAt != nil {
			if old.Rotated {
				reusedBy = old.ParentID // a used token came back: someone copied it
				return nil
			}
			return ErrSessionInvalid // signed out
		}
		if old.ExpiresAt.Before(now) {
			return ErrSessionInvalid
		}
		if err := tx.Model(&old).Updates(map[string]any{"revoked_at": now, "rotated": true}).Error; err != nil {
			return err
		}
		next := models.Session{ParentID: old.ParentID, TokenHash: newHash, Device: old.Device, ExpiresAt: expires}
		if err := tx.Create(&next).Error; err != nil {
			return err
		}
		parentID, sessionID = old.ParentID, next.ID
		return nil
	})
	if err == nil && reusedBy != "" {
		// done after the transaction above, so returning an error keeps it
		_ = s.RevokeAllSessions(ctx, reusedBy)
		return "", "", ErrSessionReused
	}
	return parentID, sessionID, err
}

// RevokeSession signs one device out.
func (s *Store) RevokeSession(ctx context.Context, parentID, sessionID string) error {
	return s.db.WithContext(ctx).Model(&models.Session{}).
		Where("id = ? AND parent_id = ? AND revoked_at IS NULL", sessionID, parentID).
		Update("revoked_at", time.Now()).Error
}

// RevokeAllSessions signs every device of the parent out.
func (s *Store) RevokeAllSessions(ctx context.Context, parentID string) error {
	return s.db.WithContext(ctx).Model(&models.Session{}).
		Where("parent_id = ? AND revoked_at IS NULL", parentID).
		Update("revoked_at", time.Now()).Error
}

// SessionActive: the session exists, is not revoked and not expired.
func (s *Store) SessionActive(ctx context.Context, sessionID string) (bool, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&models.Session{}).
		Where("id = ? AND revoked_at IS NULL AND expires_at > ?", sessionID, time.Now()).
		Count(&n).Error
	return n > 0, err
}
