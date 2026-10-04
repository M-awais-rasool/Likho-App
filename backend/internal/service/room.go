package service

import (
	"context"

	"likho/backend/internal/cache"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// RoomService: the Mascot Room. Stars are spent on the server.
type RoomService struct {
	room     *repository.RoomRepository
	cache    *cache.Cache
	activity *ActivityService
}

func NewRoomService(room *repository.RoomRepository, c *cache.Cache, activity *ActivityService) *RoomService {
	return &RoomService{room: room, cache: c, activity: activity}
}

// Tap buys the item (if affordable), or wears / takes off / places /
// removes one already owned.
func (s *RoomService) Tap(ctx context.Context, parentID, childID, itemID string) (model.RoomState, error) {
	out, err := s.room.Tap(ctx, parentID, childID, itemID)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
		if out.Action == "bought" {
			s.activity.Event(ctx, model.ActivityEvent{Type: model.EventItemBought, ParentID: &parentID, ChildID: &childID,
				Detail: model.JSONOf(map[string]any{"item": itemID, "starsLeft": out.Stars})})
		}
	}
	return out, err
}
