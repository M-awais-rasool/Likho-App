package service

import (
	"context"
	"fmt"

	"likho/backend/internal/cache"
	"likho/backend/internal/catalog"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ProgressService: finished levels. The course content decides which levels
// exist and which need Likho Plus; the rules decide stars and unlocks.
type ProgressService struct {
	progress *repository.ProgressRepository
	catalog  *catalog.Store
	cache    *cache.Cache
	activity *ActivityService
}

func NewProgressService(progress *repository.ProgressRepository, cat *catalog.Store, c *cache.Cache, activity *ActivityService) *ProgressService {
	return &ProgressService{progress: progress, catalog: cat, cache: c, activity: activity}
}

// Record saves a finished level of a course: the best stars are kept, the
// child earns the improvement (+2 the first time), the level must be
// unlocked, and Plus levels need the subscription.
func (s *ProgressService) Record(ctx context.Context, parentID, childID, courseID string, in model.ResultInput) (model.Outcome, error) {
	course, ok := s.catalog.Get().Course(courseID)
	if !ok {
		return model.Outcome{}, domain.ErrCourseNotFound
	}
	level, ok := course.Level(in.Level)
	if !ok {
		return model.Outcome{}, domain.Invalid(fmt.Sprintf("level must be a map level of this course (1 to %d)", course.Stats.Levels))
	}
	if !domain.ValidStars(in.Stars) {
		return model.Outcome{}, domain.Invalid("stars must be 1 to 3")
	}
	in.Seconds = domain.LevelSeconds(in.Seconds)

	out, err := s.progress.Record(ctx, parentID, childID, courseID, in, level.RequiresSubscription)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		s.activity.LevelCompleted(ctx, parentID, childID, courseID, out, in.Seconds, course.LastLevel())
	}
	return out, err
}
