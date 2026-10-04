package repository

import (
	"context"
	"strconv"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// ChildRepository: child profiles and everything shown for them.
type ChildRepository struct {
	db *gorm.DB
}

// Views loads the parent's children with their progress.
func (r *ChildRepository) Views(ctx context.Context, parentID string) ([]model.ChildView, error) {
	return r.views(ctx, parentID, "")
}

// View loads one child of the parent.
func (r *ChildRepository) View(ctx context.Context, parentID, childID string) (model.ChildView, error) {
	views, err := r.views(ctx, parentID, childID)
	if err != nil {
		return model.ChildView{}, err
	}
	if len(views) == 0 {
		return model.ChildView{}, domain.ErrNotFound
	}
	return views[0], nil
}

// views loads children (or just [childID]) in 4 queries whatever their
// number: children, their progress, their items, and one aggregate of play
// days.
func (r *ChildRepository) views(ctx context.Context, parentID, childID string) ([]model.ChildView, error) {
	var kids []model.Child
	q := r.db.WithContext(ctx).
		Preload("Progress").
		Preload("Items", func(db *gorm.DB) *gorm.DB { return db.Order("bought_at") }).
		Where("parent_id = ?", parentID).
		Order("created_at")
	if childID != "" {
		q = q.Where("id = ?", childID)
	}
	if err := q.Find(&kids).Error; err != nil {
		return nil, err
	}
	if len(kids) == 0 {
		return []model.ChildView{}, nil
	}

	ids := make([]string, len(kids))
	for i, k := range kids {
		ids[i] = k.ID
	}
	type stat struct {
		ChildID     string
		Days        int
		WeekSeconds int
	}
	var stats []stat
	err := r.db.WithContext(ctx).Model(&model.PlayDay{}).
		Select("child_id, count(*) AS days, COALESCE(SUM(seconds) FILTER (WHERE day >= ?), 0) AS week_seconds", startOfWeek(time.Now())).
		Where("child_id IN ?", ids).
		Group("child_id").
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}
	byChild := make(map[string]stat, len(stats))
	for _, st := range stats {
		byChild[st.ChildID] = st
	}

	views := make([]model.ChildView, len(kids))
	for i, k := range kids {
		views[i] = viewOf(k, byChild[k.ID].Days, byChild[k.ID].WeekSeconds)
	}
	return views, nil
}

func viewOf(k model.Child, days, weekSeconds int) model.ChildView {
	v := model.ChildView{
		ID: k.ID, Name: k.Name, Age: k.Age, Color: k.Color, Stars: k.Stars, Wearing: k.Wearing,
		Owned: []string{}, Room: []string{}, Progress: map[string]model.CourseProgress{},
		DaysPlayed: days, MinutesThisWeek: (weekSeconds + 59) / 60,
	}
	for _, p := range k.Progress {
		cp, ok := v.Progress[p.CourseID]
		if !ok {
			cp = model.CourseProgress{LevelStars: map[string]int{}}
			v.Progress[p.CourseID] = cp
		}
		cp.LevelStars[strconv.Itoa(p.Level)] = p.BestStars
	}
	for _, it := range k.Items {
		v.Owned = append(v.Owned, it.ItemID)
		if it.Placed {
			v.Room = append(v.Room, it.ItemID)
		}
	}
	return v
}

// startOfWeek = Monday 00:00 UTC (Postgres date_trunc('week')).
func startOfWeek(t time.Time) time.Time {
	t = t.UTC()
	d := (int(t.Weekday()) + 6) % 7
	return time.Date(t.Year(), t.Month(), t.Day()-d, 0, 0, 0, 0, time.UTC)
}

// Create adds a child (input already validated); at most domain.MaxChildren.
func (r *ChildRepository) Create(ctx context.Context, parentID string, in model.ChildInput) (model.ChildView, error) {
	c := model.Child{ParentID: parentID, Name: in.Name, Age: in.Age, Color: in.Color}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := lockParent(tx, parentID); err != nil {
			return err
		}
		var n int64
		if err := tx.Model(&model.Child{}).Where("parent_id = ?", parentID).Count(&n).Error; err != nil {
			return err
		}
		if n >= domain.MaxChildren {
			return domain.ErrTooManyChildren
		}
		return tx.Create(&c).Error
	})
	if err != nil {
		return model.ChildView{}, err
	}
	return viewOf(c, 0, 0), nil
}

// Update changes name / age / colour (already validated).
func (r *ChildRepository) Update(ctx context.Context, parentID, childID string, p model.ChildPatch) (model.ChildView, error) {
	updates := map[string]any{"updated_at": time.Now()}
	if p.Name != nil {
		updates["name"] = *p.Name
	}
	if p.Age != nil {
		updates["age"] = *p.Age
	}
	if p.Color != nil {
		updates["color"] = *p.Color
	}
	res := r.db.WithContext(ctx).Model(&model.Child{}).Where("id = ? AND parent_id = ?", childID, parentID).Updates(updates)
	if res.Error != nil {
		return model.ChildView{}, res.Error
	}
	if res.RowsAffected == 0 {
		return model.ChildView{}, domain.ErrNotFound
	}
	return r.View(ctx, parentID, childID)
}

// Delete removes a child and all its progress; the last child stays.
func (r *ChildRepository) Delete(ctx context.Context, parentID, childID string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := lockParent(tx, parentID); err != nil {
			return err
		}
		var n int64
		if err := tx.Model(&model.Child{}).Where("parent_id = ?", parentID).Count(&n).Error; err != nil {
			return err
		}
		res := tx.Where("id = ? AND parent_id = ?", childID, parentID).Delete(&model.Child{})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return domain.ErrNotFound
		}
		if n <= 1 {
			return domain.ErrLastChild // rolls the delete back
		}
		return nil
	})
}

// AdjustStars changes a child's star balance by [delta] (never below 0)
// and returns the parent and the new balance (admin panel).
func (r *ChildRepository) AdjustStars(ctx context.Context, childID string, delta int) (parentID string, stars int, err error) {
	var c model.Child
	res := r.db.WithContext(ctx).Model(&c).Clauses(clause.Returning{}).Where("id = ?", childID).
		Updates(map[string]any{"stars": gorm.Expr("GREATEST(stars + ?, 0)", delta), "updated_at": time.Now()})
	if res.Error != nil {
		return "", 0, res.Error
	}
	if res.RowsAffected == 0 {
		return "", 0, domain.ErrNotFound
	}
	return c.ParentID, c.Stars, nil
}
