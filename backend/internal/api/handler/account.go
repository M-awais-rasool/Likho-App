package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/model"
	"likho/backend/internal/service"
)

type AccountHandler struct {
	account *service.AccountService
}

// Me: GET /v1/me -> account, settings, subscription, children + progress.
// X-Cache says whether Redis answered.
func (h *AccountHandler) Me(c *gin.Context) {
	body, hit, err := h.account.MeJSON(c.Request.Context(), parentID(c))
	if err != nil {
		writeError(c, err)
		return
	}
	c.Header("X-Cache", map[bool]string{true: "hit", false: "miss"}[hit])
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

// UpdateSettings: PATCH /v1/me/settings {only the fields to change}.
func (h *AccountHandler) UpdateSettings(c *gin.Context) {
	var in model.SettingsPatch
	if !bind(c, &in) {
		return
	}
	out, err := h.account.UpdateSettings(c.Request.Context(), parentID(c), in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// StartTrial: POST /v1/me/trial -> 7 days of Likho Plus (once).
func (h *AccountHandler) StartTrial(c *gin.Context) {
	out, err := h.account.StartTrial(c.Request.Context(), parentID(c))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// Delete: DELETE /v1/me -> the account and everything in it.
func (h *AccountHandler) Delete(c *gin.Context) {
	if err := h.account.Delete(c.Request.Context(), parentID(c)); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}
