package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// ProgressRepository: finished levels, per child and course.
type ProgressRepository struct {
	db *gorm.DB
}

// Record saves a finished level of [courseID] and awards stars with the
// game's rules (best stars kept, +2 the first time). [needsPlus] = the
// level is a Likho Plus level. Input is already validated against the
// course (level exists, stars 1..3).
func (r *ProgressRepository) Record(ctx context.Context, parentID, childID, courseID string, in model.ResultInput, needsPlus bool) (model.Outcome, error) {
	var out model.Outcome
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		c, err := lockChild(tx, parentID, childID)
		if err != nil {
			return err
		}
		var p model.Parent
		if err := tx.Select("plus_until", "tester").Take(&p, "id = ?", parentID).Error; err != nil {
			return notFound(err)
		}
		// a level started just before Plus ended still counts
		if needsPlus && !p.PlusActive(time.Now().Add(-domain.PlusGrace)) {
			return domain.ErrPlusRequired
		}

		// this level and the one before it (unlock rule)
		var rows []model.LevelProgress
		if err := tx.Where("child_id = ? AND course_id = ? AND level IN ?", childID, courseID, []int{in.Level - 1, in.Level}).Find(&rows).Error; err != nil {
			return err
		}
		best := map[int]int{}
		for _, r := range rows {
			best[r.Level] = r.BestStars
		}
		// a test account plays any level
		if !p.Tester && !domain.Unlocked(in.Level, func(n int) bool { _, ok := best[n]; return ok }) {
			return domain.ErrLevelLocked
		}
		var old *int
		if b, ok := best[in.Level]; ok {
			old = &b
		}
		gain := domain.Gain(old, in.Stars)

		// keep the best result
		err = tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "child_id"}, {Name: "course_id"}, {Name: "level"}},
			DoUpdates: clause.Assignments(map[string]any{
				"best_stars": gorm.Expr("GREATEST(level_progress.best_stars, EXCLUDED.best_stars)"),
				"plays":      gorm.Expr("level_progress.plays + 1"),
				"last_at":    gorm.Expr("now()"),
			}),
		}).Create(&model.LevelProgress{ChildID: childID, CourseID: courseID, Level: in.Level, BestStars: in.Stars}).Error
		if err != nil {
			return err
		}

		// award the stars
		if gain > 0 {
			err = tx.Model(&c).Updates(map[string]any{"stars": gorm.Expr("stars + ?", gain), "updated_at": time.Now()}).Error
			if err != nil {
				return err
			}
		}

		// practice log for today (days played, minutes this week)
		today := time.Now().UTC().Truncate(24 * time.Hour)
		err = tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "child_id"}, {Name: "day"}},
			DoUpdates: clause.Assignments(map[string]any{
				"seconds": gorm.Expr("play_days.seconds + EXCLUDED.seconds"),
				"levels":  gorm.Expr("play_days.levels + 1"),
			}),
		}).Create(&model.PlayDay{ChildID: childID, Day: today, Seconds: in.Seconds, Levels: 1}).Error
		if err != nil {
			return err
		}

		out = model.Outcome{
			CourseID: courseID, Level: in.Level, Stars: in.Stars, BestStars: max(in.Stars, deref(old)),
			Gain: gain, FirstTime: old == nil, TotalStars: c.Stars + gain,
		}
		return nil
	})
	return out, err
}
