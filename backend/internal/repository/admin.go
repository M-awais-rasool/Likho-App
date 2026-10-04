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

// AdminRepository: the admin panel's own data (team, sign-ins, audit log,
// settings, alerts).
type AdminRepository struct {
	db *gorm.DB
}

// ------------------------------------------------------------------ team

func (r *AdminRepository) CountAdmins(ctx context.Context) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Model(&model.AdminUser{}).Count(&n).Error
	return n, err
}

func (r *AdminRepository) CreateAdmin(ctx context.Context, a *model.AdminUser) error {
	err := r.db.WithContext(ctx).Create(a).Error
	if errors.Is(err, gorm.ErrDuplicatedKey) {
		return domain.ErrAdminExists
	}
	return err
}

func (r *AdminRepository) AdminByEmail(ctx context.Context, email string) (model.AdminUser, error) {
	var a model.AdminUser
	err := r.db.WithContext(ctx).Take(&a, "email = ?", email).Error
	return a, notFound(err)
}

func (r *AdminRepository) Admin(ctx context.Context, id string) (model.AdminUser, error) {
	var a model.AdminUser
	err := r.db.WithContext(ctx).Take(&a, "id = ?", id).Error
	return a, notFound(err)
}

func (r *AdminRepository) Admins(ctx context.Context) ([]model.AdminUser, error) {
	var out []model.AdminUser
	err := r.db.WithContext(ctx).Order("created_at").Find(&out).Error
	return out, err
}

// UpdateAdmin changes the given columns.
func (r *AdminRepository) UpdateAdmin(ctx context.Context, id string, updates map[string]any) error {
	res := r.db.WithContext(ctx).Model(&model.AdminUser{}).Where("id = ?", id).Updates(updates)
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
}

func (r *AdminRepository) DeleteAdmin(ctx context.Context, id string) error {
	res := r.db.WithContext(ctx).Delete(&model.AdminUser{}, "id = ?", id)
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
}

// OwnersOtherThan counts enabled owners except [id] (the last owner cannot
// be removed or demoted).
func (r *AdminRepository) OwnersOtherThan(ctx context.Context, id string) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Model(&model.AdminUser{}).
		Where("role = ? AND NOT disabled AND id <> ?", model.RoleOwner, id).Count(&n).Error
	return n, err
}

// -------------------------------------------------------------- sessions

func (r *AdminRepository) CreateSession(ctx context.Context, s *model.AdminSession) error {
	return r.db.WithContext(ctx).Create(s).Error
}

// SessionAdmin returns the admin of a live session.
func (r *AdminRepository) SessionAdmin(ctx context.Context, hash []byte) (model.AdminUser, model.AdminSession, error) {
	var s model.AdminSession
	err := r.db.WithContext(ctx).
		Where("token_hash = ? AND revoked_at IS NULL AND expires_at > ?", hash, time.Now()).
		Take(&s).Error
	if err != nil {
		return model.AdminUser{}, s, notFound(err)
	}
	a, err := r.Admin(ctx, s.AdminID)
	return a, s, err
}

func (r *AdminRepository) RevokeSession(ctx context.Context, hash []byte) error {
	return r.db.WithContext(ctx).Model(&model.AdminSession{}).
		Where("token_hash = ? AND revoked_at IS NULL", hash).
		Update("revoked_at", time.Now()).Error
}

// RevokeAdminSessions signs an admin out everywhere.
func (r *AdminRepository) RevokeAdminSessions(ctx context.Context, adminID string) error {
	return r.db.WithContext(ctx).Model(&model.AdminSession{}).
		Where("admin_id = ? AND revoked_at IS NULL", adminID).
		Update("revoked_at", time.Now()).Error
}

// ----------------------------------------------------------------- audit

func (r *AdminRepository) Audit(ctx context.Context, e *model.AuditEntry) error {
	return r.db.WithContext(ctx).Create(e).Error
}

// AuditLog returns entries older than [before] (0 = newest), newest first.
func (r *AdminRepository) AuditLog(ctx context.Context, before int64, limit int) ([]model.AuditEntry, error) {
	var out []model.AuditEntry
	q := r.db.WithContext(ctx).Order("id DESC").Limit(limit)
	if before > 0 {
		q = q.Where("id < ?", before)
	}
	err := q.Find(&out).Error
	return out, err
}

// -------------------------------------------------------------- settings

// Setting reads a setting into [v]; false when it was never set.
func (r *AdminRepository) Setting(ctx context.Context, key string, v any) (bool, error) {
	var s model.AdminSetting
	err := r.db.WithContext(ctx).Take(&s, "key = ?", key).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, json.Unmarshal(s.Value, v)
}

func (r *AdminRepository) SetSetting(ctx context.Context, key string, v any) error {
	return r.db.WithContext(ctx).Clauses(clause.OnConflict{UpdateAll: true}).
		Create(&model.AdminSetting{Key: key, Value: model.JSONOf(v), UpdatedAt: time.Now()}).Error
}

// ---------------------------------------------------------------- alerts

// AlertView is an alert with the family it is about.
type AlertView struct {
	model.AdminAlert
	ParentEmail string `json:"parentEmail"`
	ChildName   string `json:"childName"`
	Country     string `json:"country"`
}

// Alerts returns alerts older than [before] (0 = newest), newest first;
// [unread] keeps only unread ones.
func (r *AdminRepository) Alerts(ctx context.Context, unread bool, before int64, limit int) ([]AlertView, error) {
	var out []AlertView
	q := r.db.WithContext(ctx).Table("admin_alerts a").
		Select("a.*, coalesce(p.email, '') AS parent_email, coalesce(c.name, '') AS child_name, coalesce(p.country, '') AS country").
		Joins("LEFT JOIN parents p ON p.id = a.parent_id").
		Joins("LEFT JOIN children c ON c.id = a.child_id").
		Order("a.id DESC").Limit(limit)
	if unread {
		q = q.Where("a.read_at IS NULL")
	}
	if before > 0 {
		q = q.Where("a.id < ?", before)
	}
	err := q.Scan(&out).Error
	return out, err
}

// UnreadAlerts counts unread alerts and returns the newest id (0 = none).
func (r *AdminRepository) UnreadAlerts(ctx context.Context) (count int64, latest int64, err error) {
	var row struct {
		N      int64
		Latest int64
	}
	err = r.db.WithContext(ctx).Raw(`SELECT count(*) AS n, coalesce(max(id), 0) AS latest FROM admin_alerts WHERE read_at IS NULL`).Scan(&row).Error
	return row.N, row.Latest, err
}

// MarkAlertsRead marks [ids] (none = all) read by [by].
func (r *AdminRepository) MarkAlertsRead(ctx context.Context, ids []int64, by string) error {
	q := r.db.WithContext(ctx).Model(&model.AdminAlert{}).Where("read_at IS NULL")
	if len(ids) > 0 {
		q = q.Where("id IN ?", ids)
	}
	return q.Updates(map[string]any{"read_at": time.Now(), "read_by": by}).Error
}
