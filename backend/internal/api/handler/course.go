package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/service"
)

type CourseHandler struct {
	courses *service.CourseService
}

// List: GET /v1/courses -> {"courses": [summary…]}.
func (h *CourseHandler) List(c *gin.Context) {
	c.Header("Cache-Control", "public, max-age=300")
	writeJSON(c, http.StatusOK, gin.H{"courses": h.courses.List()})
}

// Get: GET /v1/courses/:courseId -> the whole course (worlds, levels,
// rounds, letter guides). From memory, gzipped when the phone accepts it,
// and "304 Not Modified" when it already has this version (If-None-Match).
func (h *CourseHandler) Get(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	course, err := h.courses.Get(id)
	if err != nil {
		writeError(c, err)
		return
	}
	c.Header("ETag", course.ETag)
	c.Header("Cache-Control", "public, max-age=300")
	c.Header("Vary", "Accept-Encoding")
	if match := c.GetHeader("If-None-Match"); match != "" && strings.Contains(match, course.ETag) {
		c.Status(http.StatusNotModified)
		return
	}
	if strings.Contains(c.GetHeader("Accept-Encoding"), "gzip") {
		c.Header("Content-Encoding", "gzip")
		c.Data(http.StatusOK, "application/json; charset=utf-8", course.Gzip)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", course.JSON)
}
