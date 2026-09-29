package service

import (
	"context"

	"likho/backend/internal/cache"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// RoomService: the Mascot Room. Stars are spent on the server.
type RoomService struct {
	room  *repository.RoomRepository
	cache *cache.Cache
}

func NewRoomService(room *repository.RoomRepository, c *cache.Cache) *RoomService {
	return &RoomService{room: room, cache: c}
}

// Tap buys the item (if affordable), or wears / takes off / places /
// removes one already owned.
func (s *RoomService) Tap(ctx context.Context, parentID, childID, itemID string) (model.RoomState, error) {
	out, err := s.room.Tap(ctx, parentID, childID, itemID)
	if err == nil {
		s.cache.ForgetMe(ctx, parentID)
	}
	return out, err
}
