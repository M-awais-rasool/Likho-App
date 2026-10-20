package service

import (
	"context"

	"likho/backend/internal/cache"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// RoomService: the Mascot Room. Stars are spent on the server, at the
// prices of the App controls; hidden items cannot be tapped.
type RoomService struct {
	room     *repository.RoomRepository
	cache    *cache.Cache
	activity *ActivityService
	controls *ControlsService
}

func NewRoomService(room *repository.RoomRepository, c *cache.Cache, activity *ActivityService, controls *ControlsService) *RoomService {
	return &RoomService{room: room, cache: c, activity: activity, controls: controls}
}

// Tap buys the item (if affordable), or wears / takes off / places /
// removes one already owned.
func (s *RoomService) Tap(ctx context.Context, parentID, childID, itemID string) (model.RoomState, error) {
	if _, known := domain.Items[itemID]; !known {
		return model.RoomState{}, domain.ErrUnknownItem
	}
	item, ok := s.controls.Controls(ctx).Item(itemID)
	if !ok {
		return model.RoomState{}, domain.ErrItemUnavailable
	}
	out, err := s.room.Tap(ctx, parentID, childID, item)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		if out.Action == "bought" {
			s.activity.Event(ctx, model.ActivityEvent{Type: model.EventItemBought, ParentID: &parentID, ChildID: &childID,
				Detail: model.JSONOf(map[string]any{"item": itemID, "starsLeft": out.Stars})})
		}
	}
	return out, err
}
