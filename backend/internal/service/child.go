package service

import (
	"context"
	"strings"
	"time"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// ChildService: child profiles (up to 4 per parent).
type ChildService struct {
	children *repository.ChildRepository
	cache    *cache.Cache
}

func NewChildService(children *repository.ChildRepository, c *cache.Cache) *ChildService {
	return &ChildService{children: children, cache: c}
}

// Create adds a child. The parent picks the class; an older app sends the
// age instead, and the class is then guessed from it and left unconfirmed
// (the app asks the parent later).
func (s *ChildService) Create(ctx context.Context, parentID string, in model.ChildInput) (model.ChildView, error) {
	name, ok := domain.CleanName(in.Name)
	switch {
	case !ok:
		return model.ChildView{}, domain.Invalid("name must be 1 to 14 characters")
	case in.Age != nil && !domain.ValidAge(*in.Age):
		return model.ChildView{}, domain.Invalid("age must be 5 to 8")
	case in.Grade == "" && in.Age == nil, in.Grade != "" && !domain.ValidGrade(in.Grade):
		return model.ChildView{}, domain.Invalid("grade must be " + domain.GradeList())
	case !domain.ValidColor(in.Color):
		return model.ChildView{}, domain.Invalid("color must be one of the six Pencil colours")
	}
	c := model.Child{Name: name, Age: in.Age, Grade: in.Grade, Color: strings.ToUpper(in.Color)}
	if c.Grade == "" {
		c.Grade = domain.GradeForAge(*in.Age)
	} else {
		now := time.Now().UTC()
		c.GradeConfirmedAt = &now
	}
	c.UnlockedGrade = c.Grade
	out, err := s.children.Create(ctx, parentID, c)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
	}
	return out, err
}

// Update changes only the fields that are sent. Sending the class counts as
// a parent confirming it; a new class locks the classes above it again, and
// unlockedGrade opens classes up to it (domain.ChangeGrade).
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
	if in.Grade != nil && !domain.ValidGrade(*in.Grade) {
		return model.ChildView{}, domain.Invalid("grade must be " + domain.GradeList())
	}
	if in.UnlockedGrade != nil && !domain.ValidGrade(*in.UnlockedGrade) {
		return model.ChildView{}, domain.Invalid("unlockedGrade must be " + domain.GradeList())
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
	}
	return err
}
