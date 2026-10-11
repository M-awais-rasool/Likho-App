package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/model"
)

// PlayRepository: Google Play purchases of Likho Plus and the Plus they
// give.
type PlayRepository struct {
	db *gorm.DB
}

// Get returns the purchase with this token (found = false: not seen yet).
func (r *PlayRepository) Get(ctx context.Context, token string) (s model.PlaySubscription, found bool, err error) {
	err = r.db.WithContext(ctx).Take(&s, "purchase_token = ?", token).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return s, false, nil
	}
	return s, err == nil, err
}

// Save inserts or updates the purchase.
func (r *PlayRepository) Save(ctx context.Context, s *model.PlaySubscription) error {
	return r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "purchase_token"}},
		DoUpdates: clause.AssignmentColumns([]string{"parent_id", "product_id", "base_plan_id", "offer_id", "state", "expires_at",
			"auto_renewing", "acknowledged", "order_id", "linked_token", "test", "updated_at"}),
	}).Create(s).Error
}

// ForParent returns the account's purchases, the one that ends last first.
func (r *PlayRepository) ForParent(ctx context.Context, parentID string) ([]model.PlaySubscription, error) {
	var out []model.PlaySubscription
	err := r.db.WithContext(ctx).Where("parent_id = ?", parentID).Order("expires_at DESC").Find(&out).Error
	return out, err
}

// ParentByAccountHash finds the account whose StoreAccountID is [hash]
// (sha256 of "likho:" + the account ID, as service.StoreAccountID).
func (r *PlayRepository) ParentByAccountHash(ctx context.Context, hash string) (string, bool, error) {
	var ids []string
	err := r.db.WithContext(ctx).Raw(
		`SELECT id FROM parents WHERE encode(sha256(convert_to('likho:' || id::text, 'UTF8')), 'hex') = ? LIMIT 1`, hash).Scan(&ids).Error
	if err != nil || len(ids) == 0 {
		return "", false, err
	}
	return ids[0], true, nil
}

// ExtendPlus makes Likho Plus last at least until [until].
func (r *PlayRepository) ExtendPlus(ctx context.Context, parentID string, until time.Time) (bool, error) {
	res := r.db.WithContext(ctx).Model(&model.Parent{}).
		Where("id = ? AND (plus_until IS NULL OR plus_until < ?)", parentID, until).
		Update("plus_until", until)
	return res.RowsAffected > 0, res.Error
}

// EndPlusFrom ends Likho Plus at [to], but only when it still runs to
// [from] (the purchase gave it): a trial or a grant that lasts longer is
// kept.
func (r *PlayRepository) EndPlusFrom(ctx context.Context, parentID string, from, to time.Time) (bool, error) {
	res := r.db.WithContext(ctx).Model(&model.Parent{}).
		Where("id = ? AND plus_until = ?", parentID, from).
		Update("plus_until", to)
	return res.RowsAffected > 0, res.Error
}
