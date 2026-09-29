package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/game"
	"likho/backend/models"
)

// lockChild loads the child (checking it belongs to the parent) and locks
// its row until the transaction ends, so two requests can never spend or
// award the same stars twice.
func lockChild(tx *gorm.DB, parentID, childID string) (models.Child, error) {
	var c models.Child
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("id = ? AND parent_id = ?", childID, parentID).
		Take(&c).Error
	return c, notFound(err)
}

// RecordResult saves a finished level and awards stars with the game's
// rules (best stars kept, +2 the first time). [needsPlus] = the level is a
// Likho Plus level. Input is already validated (level 1..36, stars 1..3).
func (s *Store) RecordResult(ctx context.Context, parentID, childID string, in models.ResultInput, needsPlus bool) (models.Outcome, error) {
	var out models.Outcome
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		c, err := lockChild(tx, parentID, childID)
		if err != nil {
			return err
		}
		if needsPlus {
			var p models.Parent
			if err := tx.Select("plus_until").Take(&p, "id = ?", parentID).Error; err != nil {
				return notFound(err)
			}
			if !p.PlusActive(time.Now()) {
				return ErrPlusRequired
			}
		}

		// this level and the one before it (unlock rule)
		var rows []models.LevelResult
		if err := tx.Where("child_id = ? AND level IN ?", childID, []int{in.Level - 1, in.Level}).Find(&rows).Error; err != nil {
			return err
		}
		best := map[int]int{}
		for _, r := range rows {
			best[r.Level] = r.BestStars
		}
		if !game.Unlocked(in.Level, func(n int) bool { _, ok := best[n]; return ok }) {
			return ErrLevelLocked
		}
		var old *int
		if b, ok := best[in.Level]; ok {
			old = &b
		}
		gain := game.Gain(old, in.Stars)

		// keep the best result
		err = tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "child_id"}, {Name: "level"}},
			DoUpdates: clause.Assignments(map[string]any{
				"best_stars": gorm.Expr("GREATEST(level_results.best_stars, EXCLUDED.best_stars)"),
				"plays":      gorm.Expr("level_results.plays + 1"),
				"last_at":    gorm.Expr("now()"),
			}),
		}).Create(&models.LevelResult{ChildID: childID, Level: in.Level, BestStars: in.Stars}).Error
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
		}).Create(&models.PlayDay{ChildID: childID, Day: today, Seconds: in.Seconds, Levels: 1}).Error
		if err != nil {
			return err
		}

		out = models.Outcome{
			Level: in.Level, Stars: in.Stars, BestStars: max(in.Stars, deref(old)),
			Gain: gain, FirstTime: old == nil, TotalStars: c.Stars + gain,
		}
		return nil
	})
	return out, err
}

// TapItem is a tap on a Mascot Room item: buy it (if affordable), or wear /
// take off / place / remove it once owned.
func (s *Store) TapItem(ctx context.Context, parentID, childID, itemID string) (models.RoomState, error) {
	item, ok := game.Items[itemID]
	if !ok {
		return models.RoomState{}, ErrUnknownItem
	}
	var st models.RoomState
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		c, err := lockChild(tx, parentID, childID)
		if err != nil {
			return err
		}
		var owned []models.ChildItem
		if err := tx.Where("child_id = ?", childID).Order("bought_at").Find(&owned).Error; err != nil {
			return err
		}
		var have *models.ChildItem
		for i := range owned {
			if owned[i].ItemID == itemID {
				have = &owned[i]
			}
		}

		action, ok := game.Tap(item, have != nil, c.Stars, c.Wearing, have != nil && have.Placed)
		if !ok {
			return ErrNotEnoughStars
		}
		childUpdates := map[string]any{"updated_at": time.Now()}
		switch action {
		case game.Bought:
			bought := models.ChildItem{ChildID: childID, ItemID: itemID, Placed: !item.Wear, BoughtAt: time.Now()}
			if err := tx.Create(&bought).Error; err != nil {
				return err
			}
			owned = append(owned, bought)
			c.Stars -= item.Price
			childUpdates["stars"] = gorm.Expr("stars - ?", item.Price)
			if item.Wear {
				c.Wearing = &item.ID
				childUpdates["wearing"] = item.ID
			}
		case game.Worn:
			c.Wearing = &item.ID
			childUpdates["wearing"] = item.ID
		case game.TakenOff:
			c.Wearing = nil
			childUpdates["wearing"] = nil
		case game.Placed, game.Removed:
			have.Placed = action == game.Placed
			if err := tx.Model(&models.ChildItem{}).Where("child_id = ? AND item_id = ?", childID, itemID).Update("placed", have.Placed).Error; err != nil {
				return err
			}
		}
		if err := tx.Model(&c).Updates(childUpdates).Error; err != nil {
			return err
		}

		st = models.RoomState{Action: action, Stars: c.Stars, Wearing: c.Wearing, Owned: []string{}, Room: []string{}}
		for _, it := range owned {
			st.Owned = append(st.Owned, it.ItemID)
			if it.Placed {
				st.Room = append(st.Room, it.ItemID)
			}
		}
		return nil
	})
	return st, err
}
