package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/domain"
	"likho/backend/internal/service"
)

// The Google Play closed test (admin panel): testers, whose account is
// whose, and the days each of them used the app.

// ClosedTestBoard: GET /closed-test.
func (h *AdminHandler) ClosedTestBoard(c *gin.Context) {
	out, err := h.ClosedTest.Board(c.Request.Context())
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// SetClosedTestSettings: PUT /closed-test/settings (ClosedTestSettings).
func (h *AdminHandler) SetClosedTestSettings(c *gin.Context) {
	var in service.ClosedTestSettings
	if !bind(c, &in) {
		return
	}
	out, err := h.ClosedTest.SetSettings(c.Request.Context(), actor(c), in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// AddTesters: POST /closed-test/testers {"testers": [{"name", "email", "phone", "note"}]}.
func (h *AdminHandler) AddTesters(c *gin.Context) {
	var in struct{ Testers []service.TesterIn }
	if !bind(c, &in) {
		return
	}
	added, skipped, err := h.ClosedTest.AddTesters(c.Request.Context(), actor(c), in.Testers)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusCreated, gin.H{"added": added, "skipped": skipped})
}

// UpdateTester: PATCH /closed-test/testers/:id {"name", "email", "phone", "note"}.
func (h *AdminHandler) UpdateTester(c *gin.Context) {
	id, ok := uuidParam(c, "id")
	if !ok {
		return
	}
	var in service.TesterIn
	if !bind(c, &in) {
		return
	}
	out, err := h.ClosedTest.UpdateTester(c.Request.Context(), actor(c), id, in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// DeleteTester: DELETE /closed-test/testers/:id.
func (h *AdminHandler) DeleteTester(c *gin.Context) {
	id, ok := uuidParam(c, "id")
	if !ok {
		return
	}
	if err := h.ClosedTest.DeleteTester(c.Request.Context(), actor(c), id); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

// LinkTestAccount: PUT /closed-test/accounts/:parentId {"testerId": id | null}
// (null: the account is not a tester's).
func (h *AdminHandler) LinkTestAccount(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	var in struct {
		TesterID *string `json:"testerId"`
	}
	if !bind(c, &in) {
		return
	}
	if in.TesterID != nil && !uuidRe.MatchString(*in.TesterID) {
		writeError(c, domain.ErrNotFound)
		return
	}
	if err := h.ClosedTest.LinkAccount(c.Request.Context(), actor(c), id, in.TesterID); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

// UnlinkTestAccount: DELETE /closed-test/accounts/:parentId.
func (h *AdminHandler) UnlinkTestAccount(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	if err := h.ClosedTest.UnlinkAccount(c.Request.Context(), actor(c), id); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}
