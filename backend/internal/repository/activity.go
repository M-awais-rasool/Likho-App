package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/model"
)

// ActivityRepository: what families do (events, active days, where they
// are) and the alerts it raises for the team.
type ActivityRepository struct {
	db *gorm.DB
}

// Add saves an event.
func (r *ActivityRepository) Add(ctx context.Context, ev *model.ActivityEvent) error {
	if ev.At.IsZero() {
		ev.At = time.Now()
	}
	return r.db.WithContext(ctx).Create(ev).Error
}

// Seen is what is known about a parent's device right now.
type Seen struct {
	Country, CountrySource, Platform, AppVersion string
}

// Touch marks the parent as active now (last seen, today's active day) and
// keeps their country and device up to date. Empty fields keep the stored
// value; a country from a less trusted source never replaces a better one.
func (r *ActivityRepository) Touch(ctx context.Context, parentID string, s Seen) error {
	now := time.Now()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		updates := map[string]any{"last_seen_at": now}
		if s.Platform != "" {
			updates["platform"] = s.Platform
		}
		if s.AppVersion != "" {
			updates["app_version"] = s.AppVersion
		}
		if s.Country != "" {
			// device < ip < cdn: only replace with an equal or better source
			rank := gorm.Expr(`CASE country_source WHEN 'cdn' THEN 3 WHEN 'ip' THEN 2 WHEN 'device' THEN 1 ELSE 0 END`)
			better := map[string]int{"cdn": 3, "ip": 2, "device": 1}[s.CountrySource]
			updates["country"] = gorm.Expr("CASE WHEN ? >= ? THEN ? ELSE country END", better, rank, s.Country)
			updates["country_source"] = gorm.Expr("CASE WHEN ? >= ? THEN ? ELSE country_source END", better, rank, s.CountrySource)
		}
		if err := tx.Model(&model.Parent{}).Where("id = ?", parentID).Updates(updates).Error; err != nil {
			return err
		}
		day := now.UTC().Truncate(24 * time.Hour)
		return tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&model.ActiveDay{ParentID: parentID, Day: day}).Error
	})
}

// AddAlert saves an alert once: false when one with the same key exists.
func (r *ActivityRepository) AddAlert(ctx context.Context, a *model.AdminAlert) (bool, error) {
	res := r.db.WithContext(ctx).Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "key"}}, DoNothing: true}).Create(a)
	return res.RowsAffected == 1, res.Error
}

// Learner is a child with their family, as alerts describe them.
type Learner struct {
	ChildName, ParentEmail, ParentName, Country string
}

func (r *ActivityRepository) Learner(ctx context.Context, childID string) (Learner, error) {
	var l Learner
	err := r.db.WithContext(ctx).Raw(`
		SELECT c.name AS child_name, p.email AS parent_email, p.name AS parent_name, p.country
		FROM children c JOIN parents p ON p.id = c.parent_id WHERE c.id = ?`, childID).Scan(&l).Error
	return l, err
}
