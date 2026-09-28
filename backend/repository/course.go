package repository

import (
	"context"
	"time"

	"gorm.io/gorm/clause"

	"likho/backend/models"
)

// LatestCourse returns the newest course content.
func (s *Store) LatestCourse(ctx context.Context) (models.CourseVersion, error) {
	var cv models.CourseVersion
	err := s.db.WithContext(ctx).Order("created_at DESC, id DESC").Take(&cv).Error
	return cv, notFound(err)
}

// SaveCourse stores course content as the newest version (a version seen
// before is simply made the newest again).
func (s *Store) SaveCourse(ctx context.Context, sha256, body string) error {
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "sha256"}},
		DoUpdates: clause.Assignments(map[string]any{"created_at": time.Now()}),
	}).Create(&models.CourseVersion{Sha256: sha256, Body: body, CreatedAt: time.Now()}).Error
}
