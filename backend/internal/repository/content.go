package repository

import (
	"context"
	"time"

	"gorm.io/gorm"

	"likho/backend/internal/model"
)

// ContentRepository: levels and worlds written in the admin panel (laid
// over the files in content/, see internal/catalog.Overlay).
type ContentRepository struct {
	db *gorm.DB
}

func (r *ContentRepository) Levels(ctx context.Context, courseID string) ([]model.ContentLevel, error) {
	var out []model.ContentLevel
	q := r.db.WithContext(ctx).Order("course_id, number")
	if courseID != "" {
		q = q.Where("course_id = ?", courseID)
	}
	return out, q.Find(&out).Error
}

func (r *ContentRepository) Level(ctx context.Context, courseID string, number int) (model.ContentLevel, error) {
	var l model.ContentLevel
	err := r.db.WithContext(ctx).Take(&l, "course_id = ? AND number = ?", courseID, number).Error
	return l, notFound(err)
}

// SaveLevel creates or replaces a level.
func (r *ContentRepository) SaveLevel(ctx context.Context, l *model.ContentLevel) error {
	l.UpdatedAt = time.Now()
	return r.db.WithContext(ctx).Save(l).Error
}

func (r *ContentRepository) DeleteLevel(ctx context.Context, courseID string, number int) error {
	return r.db.WithContext(ctx).Delete(&model.ContentLevel{}, "course_id = ? AND number = ?", courseID, number).Error
}

func (r *ContentRepository) Worlds(ctx context.Context, courseID string) ([]model.ContentWorld, error) {
	var out []model.ContentWorld
	q := r.db.WithContext(ctx).Order(`course_id, "order"`)
	if courseID != "" {
		q = q.Where("course_id = ?", courseID)
	}
	return out, q.Find(&out).Error
}

func (r *ContentRepository) SaveWorld(ctx context.Context, w *model.ContentWorld) error {
	w.UpdatedAt = time.Now()
	return r.db.WithContext(ctx).Save(w).Error
}

func (r *ContentRepository) DeleteWorld(ctx context.Context, courseID, folder string) error {
	return r.db.WithContext(ctx).Delete(&model.ContentWorld{}, "course_id = ? AND folder = ?", courseID, folder).Error
}
