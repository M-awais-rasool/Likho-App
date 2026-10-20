package repository

import (
	"context"
	"time"

	"gorm.io/gorm"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// RoomRepository: the Mascot Room (buying, wearing and placing items).
type RoomRepository struct {
	db *gorm.DB
}

// Tap is a tap on a Mascot Room item (at its current price): buy it (if
// affordable), or wear / take off / place / remove it once owned.
func (r *RoomRepository) Tap(ctx context.Context, parentID, childID string, item domain.Item) (model.RoomState, error) {
	itemID := item.ID
	var st model.RoomState
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		c, err := lockChild(tx, parentID, childID)
		if err != nil {
			return err
		}
		var owned []model.ChildItem
		if err := tx.Where("child_id = ?", childID).Order("bought_at").Find(&owned).Error; err != nil {
			return err
		}
		var have *model.ChildItem
		for i := range owned {
			if owned[i].ItemID == itemID {
				have = &owned[i]
			}
		}

		action, ok := domain.Tap(item, have != nil, c.Stars, c.Wearing, have != nil && have.Placed)
		if !ok {
			return domain.ErrNotEnoughStars
		}
		childUpdates := map[string]any{"updated_at": time.Now()}
		switch action {
		case domain.Bought:
			bought := model.ChildItem{ChildID: childID, ItemID: itemID, Placed: !item.Wear, BoughtAt: time.Now()}
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
		case domain.Worn:
			c.Wearing = &item.ID
			childUpdates["wearing"] = item.ID
		case domain.TakenOff:
			c.Wearing = nil
			childUpdates["wearing"] = nil
		case domain.Placed, domain.Removed:
			have.Placed = action == domain.Placed
			if err := tx.Model(&model.ChildItem{}).Where("child_id = ? AND item_id = ?", childID, itemID).Update("placed", have.Placed).Error; err != nil {
				return err
			}
		}
		if err := tx.Model(&c).Updates(childUpdates).Error; err != nil {
			return err
		}

		st = model.RoomState{Action: action, Stars: c.Stars, Wearing: c.Wearing, Owned: []string{}, Room: []string{}}
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
