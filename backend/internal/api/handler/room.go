package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/service"
)

type RoomHandler struct {
	room *service.RoomService
}

// Tap: POST /v1/children/:childId/room/:itemId -> the room after it
// (buy, wear / take off, place / remove).
func (h *RoomHandler) Tap(c *gin.Context) {
	child, ok := childID(c)
	if !ok {
		return
	}
	out, err := h.room.Tap(c.Request.Context(), parentID(c), child, c.Param("itemId"))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}
