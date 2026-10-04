package service

import (
	"context"
	"strings"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ChildService: child profiles (up to 4 per parent).
type ChildService struct {
	children *repository.ChildRepository
	cache    *cache.Cache
	activity *ActivityService
}

func NewChildService(children *repository.ChildRepository, c *cache.Cache, activity *ActivityService) *ChildService {
	return &ChildService{children: children, cache: c, activity: activity}
}

func (s *ChildService) Create(ctx context.Context, parentID string, in model.ChildInput) (model.ChildView, error) {
	name, ok := domain.CleanName(in.Name)
	switch {
	case !ok:
		return model.ChildView{}, domain.Invalid("name must be 1 to 14 characters")
	case !domain.ValidAge(in.Age):
		return model.ChildView{}, domain.Invalid("age must be 5 to 8")
	case !domain.ValidColor(in.Color):
		return model.ChildView{}, domain.Invalid("color must be one of the six Pencil colours")
	}
	in.Name, in.Color = name, strings.ToUpper(in.Color)
	out, err := s.children.Create(ctx, parentID, in)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		s.activity.Event(ctx, model.ActivityEvent{Type: model.EventChildAdded, ParentID: &parentID, ChildID: &out.ID,
			Detail: model.JSONOf(map[string]any{"age": out.Age})})
	}
	return out, err
}

// Update changes only the fields that are sent.
func (s *ChildService) Update(ctx context.Context, parentID, childID string, in model.ChildPatch) (model.ChildView, error) {
	if in.Name != nil {
		name, ok := domain.CleanName(*in.Name)
		if !ok {
			return model.ChildView{}, domain.Invalid("name must be 1 to 14 characters")
		}
		in.Name = &name
	}
	if in.Age != nil && !domain.ValidAge(*in.Age) {
		return model.ChildView{}, domain.Invalid("age must be 5 to 8")
	}
	if in.Color != nil {
		if !domain.ValidColor(*in.Color) {
			return model.ChildView{}, domain.Invalid("color must be one of the six Pencil colours")
		}
		up := strings.ToUpper(*in.Color)
		in.Color = &up
	}
	out, err := s.children.Update(ctx, parentID, childID, in)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
	}
	return out, err
}

// Delete removes a child and their progress (never the only child).
func (s *ChildService) Delete(ctx context.Context, parentID, childID string) error {
	err := s.children.Delete(ctx, parentID, childID)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		s.activity.Event(ctx, model.ActivityEvent{Type: model.EventChildRemoved, ParentID: &parentID, ChildID: &childID})
	}
	return err
}
