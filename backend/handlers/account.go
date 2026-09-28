package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/game"
	"likho/backend/models"
	"likho/backend/repository"
)

// Me: GET /v1/me -> account, settings, subscription, children + progress.
// Served from Redis when cached (dropped on every change).
func (h *Handler) Me(c *gin.Context) {
	ctx, id := c.Request.Context(), parentID(c)
	if body, ok := h.Cache.Me(ctx, id); ok {
		c.Header("X-Cache", "hit")
		c.Data(http.StatusOK, "application/json; charset=utf-8", body)
		return
	}
	me, err := h.Store.Me(ctx, id)
	if errors.Is(err, repository.ErrNotFound) {
		fail(c, http.StatusUnauthorized, "account_deleted", "This account no longer exists")
		return
	}
	if err != nil {
		failErr(c, err)
		return
	}
	body, err := json.Marshal(me)
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.SetMe(ctx, id, body)
	c.Header("X-Cache", "miss")
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

// UpdateSettings: PATCH /v1/me/settings {only the fields to change}.
func (h *Handler) UpdateSettings(c *gin.Context) {
	var in models.SettingsPatch
	if !bind(c, &in) {
		return
	}
	if in.SessionMinutes != nil && !game.ValidSessionMinutes(*in.SessionMinutes) {
		badInput(c, "sessionMinutes must be 5, 10 or 15")
		return
	}
	out, err := h.Store.UpdateSettings(c.Request.Context(), parentID(c), in)
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.JSON(http.StatusOK, out)
}

// StartTrial: POST /v1/me/trial -> 7 days of Likho Plus (once).
// Store purchases (App Store / Google Play) will extend plusUntil later.
func (h *Handler) StartTrial(c *gin.Context) {
	out, err := h.Store.StartTrial(c.Request.Context(), parentID(c))
	if err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.JSON(http.StatusOK, out)
}

// DeleteAccount: DELETE /v1/me -> the account and everything in it.
func (h *Handler) DeleteAccount(c *gin.Context) {
	if err := h.Store.DeleteAccount(c.Request.Context(), parentID(c)); err != nil {
		failErr(c, err)
		return
	}
	h.Cache.ForgetMe(c.Request.Context(), parentID(c))
	c.Status(http.StatusNoContent)
}
