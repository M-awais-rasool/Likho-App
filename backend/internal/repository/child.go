package repository

import (
	"context"
	"strconv"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/game"
	"likho/backend/models"
)

// childViews loads the parent's children (or just [childID]) with their
// progress in 4 queries whatever the number of children: children, their
// level results, their items, and one aggregate for play days.
func (s *Store) childViews(ctx context.Context, parentID, childID string) ([]models.ChildView, error) {
	var kids []models.Child
	q := s.db.WithContext(ctx).
		Preload("LevelResults").
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
		return []models.ChildView{}, nil
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
	weekStart := startOfWeek(time.Now())
	err := s.db.WithContext(ctx).Model(&models.PlayDay{}).
		Select("child_id, count(*) AS days, COALESCE(SUM(seconds) FILTER (WHERE day >= ?), 0) AS week_seconds", weekStart).
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

	views := make([]models.ChildView, len(kids))
	for i, k := range kids {
		views[i] = viewOf(k, byChild[k.ID].Days, byChild[k.ID].WeekSeconds)
	}
	return views, nil
}

func viewOf(k models.Child, days, weekSeconds int) models.ChildView {
	v := models.ChildView{
		ID: k.ID, Name: k.Name, Age: k.Age, Color: k.Color, Stars: k.Stars, Wearing: k.Wearing,
		Owned: []string{}, Room: []string{}, LevelStars: make(map[string]int, len(k.LevelResults)),
		DaysPlayed: days, MinutesThisWeek: (weekSeconds + 59) / 60,
	}
	for _, r := range k.LevelResults {
		v.LevelStars[strconv.Itoa(r.Level)] = r.BestStars
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

func (s *Store) Child(ctx context.Context, parentID, childID string) (models.ChildView, error) {
	views, err := s.childViews(ctx, parentID, childID)
	if err != nil {
		return models.ChildView{}, err
	}
	if len(views) == 0 {
		return models.ChildView{}, ErrNotFound
	}
	return views[0], nil
}

// lockParent locks the parent row for the rest of the transaction, so
// counting and changing children cannot race.
func lockParent(tx *gorm.DB, parentID string) error {
	var p models.Parent
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Select("id").Take(&p, "id = ?", parentID).Error
	return notFound(err)
}

// CreateChild adds a child (input already validated); at most 4.
func (s *Store) CreateChild(ctx context.Context, parentID string, in models.ChildInput) (models.ChildView, error) {
	c := models.Child{ParentID: parentID, Name: in.Name, Age: in.Age, Color: in.Color}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := lockParent(tx, parentID); err != nil {
			return err
		}
		var n int64
		if err := tx.Model(&models.Child{}).Where("parent_id = ?", parentID).Count(&n).Error; err != nil {
			return err
		}
		if n >= game.MaxChildren {
			return ErrTooManyChildren
		}
		return tx.Create(&c).Error
	})
	if err != nil {
		return models.ChildView{}, err
	}
	return viewOf(c, 0, 0), nil
}

// UpdateChild changes name / age / colour (already validated).
func (s *Store) UpdateChild(ctx context.Context, parentID, childID string, p models.ChildPatch) (models.ChildView, error) {
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
	res := s.db.WithContext(ctx).Model(&models.Child{}).Where("id = ? AND parent_id = ?", childID, parentID).Updates(updates)
	if res.Error != nil {
		return models.ChildView{}, res.Error
	}
	if res.RowsAffected == 0 {
		return models.ChildView{}, ErrNotFound
	}
	return s.Child(ctx, parentID, childID)
}

// DeleteChild removes a child and all its progress; the last child stays.
func (s *Store) DeleteChild(ctx context.Context, parentID, childID string) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := lockParent(tx, parentID); err != nil {
			return err
		}
		var n int64
		if err := tx.Model(&models.Child{}).Where("parent_id = ?", parentID).Count(&n).Error; err != nil {
			return err
		}
		res := tx.Where("id = ? AND parent_id = ?", childID, parentID).Delete(&models.Child{})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrNotFound
		}
		if n <= 1 {
			return ErrLastChild // rolls the delete back
		}
		return nil
	})
}
