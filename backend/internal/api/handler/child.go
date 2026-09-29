package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/model"
	"likho/backend/internal/service"
)

type ChildHandler struct {
	children *service.ChildService
}

// Create: POST /v1/children {"name", "age", "color"} (up to 4).
func (h *ChildHandler) Create(c *gin.Context) {
	var in model.ChildInput
	if !bind(c, &in) {
		return
	}
	out, err := h.children.Create(c.Request.Context(), parentID(c), in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusCreated, out)
}

// Update: PATCH /v1/children/:childId {only the fields to change}.
func (h *ChildHandler) Update(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	var in model.ChildPatch
	if !bind(c, &in) {
		return
	}
	out, err := h.children.Update(c.Request.Context(), parentID(c), id, in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// Delete: DELETE /v1/children/:childId (never the only child).
func (h *ChildHandler) Delete(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	if err := h.children.Delete(c.Request.Context(), parentID(c), id); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}
