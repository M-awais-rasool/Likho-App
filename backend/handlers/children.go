package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/game"
	"likho/backend/models"
)

// CreateChild: POST /v1/children {"name","age","color"} (up to 4).
func (h *Handler) CreateChild(c *gin.Context) {
	var in models.ChildInput
	if !bind(c, &in) {
		return
	}
	name, ok := game.CleanName(in.Name)
	switch {
	case !ok:
		badInput(c, "name must be 1 to 14 characters")
		return
	case !game.ValidAge(in.Age):
		badInput(c, "age must be 5 to 8")
		return
	case !game.ValidColor(in.Color):
		badInput(c, "color must be one of the six Pencil colours")
		return
	}
	in.Name, in.Color = name, strings.ToUpper(in.Color)
	out, err := h.Store.CreateChild(c.Request.Context(), parentID(c), in)
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.JSON(http.StatusCreated, out)
}

// UpdateChild: PATCH /v1/children/:id {only the fields to change}.
func (h *Handler) UpdateChild(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	var in models.ChildPatch
	if !bind(c, &in) {
		return
	}
	if in.Name != nil {
		name, ok := game.CleanName(*in.Name)
		if !ok {
			badInput(c, "name must be 1 to 14 characters")
			return
		}
		in.Name = &name
	}
	if in.Age != nil && !game.ValidAge(*in.Age) {
		badInput(c, "age must be 5 to 8")
		return
	}
	if in.Color != nil {
		if !game.ValidColor(*in.Color) {
			badInput(c, "color must be one of the six Pencil colours")
			return
		}
		up := strings.ToUpper(*in.Color)
		in.Color = &up
	}
	out, err := h.Store.UpdateChild(c.Request.Context(), parentID(c), id, in)
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.JSON(http.StatusOK, out)
}

// DeleteChild: DELETE /v1/children/:id (never the only child).
func (h *Handler) DeleteChild(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	if err := h.Store.DeleteChild(c.Request.Context(), parentID(c), id); err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.Status(http.StatusNoContent)
}

// RecordResult: POST /v1/children/:id/results {"level","stars","seconds"}
// A finished level. The server awards the stars (best kept, +2 the first
// time), checks the level is unlocked and, for Plus levels, the
// subscription. Send an "Idempotency-Key" header: a retried request gets
// the first answer again instead of stars twice.
func (h *Handler) RecordResult(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	var in models.ResultInput
	if !bind(c, &in) {
		return
	}
	level, known := h.Course.Level(in.Level)
	switch {
	case !known:
		badInput(c, "level must be a map level (1 to 36)")
		return
	case in.Stars < 1 || in.Stars > 3:
		badInput(c, "stars must be 1 to 3")
		return
	}
	if in.Seconds <= 0 {
		in.Seconds = 180 // the prototype counts 3 minutes per level
	}
	in.Seconds = min(in.Seconds, 1800)

	ctx, pid := c.Request.Context(), parentID(c)
	key := c.GetHeader("Idempotency-Key")
	if len(key) > 100 {
		badInput(c, "Idempotency-Key is too long")
		return
	}
	if key != "" {
		first, saved := h.Cache.ClaimIdempotency(ctx, pid, key)
		if !first {
			if saved == nil {
				fail(c, http.StatusConflict, "in_progress", "The same request is still running")
				return
			}
			c.Header("Idempotent-Replay", "true")
			c.Data(http.StatusOK, "application/json; charset=utf-8", saved)
			return
		}
	}

	out, err := h.Store.RecordResult(ctx, pid, id, in, level.RequiresSubscription)
	if err != nil {
		if key != "" {
			h.Cache.ReleaseIdempotency(ctx, pid, key)
		}
		failErr(c, err)
		return
	}
	body, _ := json.Marshal(out)
	if key != "" {
		h.Cache.SaveIdempotency(ctx, pid, key, body)
	}
	h.Cache.ForgetMe(ctx, pid)
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

// TapItem: POST /v1/children/:id/room/:item
// Mascot Room: buys the item (stars are spent on the server), or wears /
// takes off / places / removes one already owned.
func (h *Handler) TapItem(c *gin.Context) {
	id, ok := childID(c)
	if !ok {
		return
	}
	out, err := h.Store.TapItem(c.Request.Context(), parentID(c), id, c.Param("item"))
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.JSON(http.StatusOK, out)
}
