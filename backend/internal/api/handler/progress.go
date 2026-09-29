package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/model"
	"likho/backend/internal/service"
)

type ProgressHandler struct {
	progress *service.ProgressService
}

// Record: POST /v1/children/:childId/courses/:courseId/results
// {"level", "stars", "seconds"} -> the outcome (stars earned, best, total).
// Send an Idempotency-Key header so a retry never counts twice.
func (h *ProgressHandler) Record(c *gin.Context) {
	child, ok := childID(c)
	if !ok {
		return
	}
	course, ok := courseID(c)
	if !ok {
		return
	}
	var in model.ResultInput
	if !bind(c, &in) {
		return
	}
	out, err := h.progress.Record(c.Request.Context(), parentID(c), child, course, in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}
