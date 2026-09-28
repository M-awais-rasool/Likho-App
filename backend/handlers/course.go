package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// GetCourse: GET /v1/course -> the course content (worlds, levels, rounds).
// Answered from memory, gzipped when the phone accepts it, and "304 Not
// Modified" when the phone already has this version (If-None-Match).
func (h *Handler) GetCourse(c *gin.Context) {
	cur := h.Course.Current()
	if cur == nil {
		fail(c, http.StatusServiceUnavailable, "course_unavailable", "Course is not loaded yet")
		return
	}
	c.Header("ETag", cur.ETag)
	c.Header("Cache-Control", "public, max-age=300")
	c.Header("Vary", "Accept-Encoding")
	if match := c.GetHeader("If-None-Match"); match != "" && strings.Contains(match, cur.ETag) {
		c.Status(http.StatusNotModified)
		return
	}
	if strings.Contains(c.GetHeader("Accept-Encoding"), "gzip") {
		c.Header("Content-Encoding", "gzip")
		c.Data(http.StatusOK, "application/json; charset=utf-8", cur.Gzip)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", cur.JSON)
}

// Health: GET /healthz -> the process is up (for the load balancer).
func (h *Handler) Health(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) }

// Ready: GET /readyz -> Postgres and Redis answer.
func (h *Handler) Ready(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	status := gin.H{"postgres": "ok", "redis": "ok"}
	code := http.StatusOK
	if db, err := h.DB.DB(); err != nil || db.PingContext(ctx) != nil {
		status["postgres"], code = "down", http.StatusServiceUnavailable
	}
	if h.Redis.Ping(ctx).Err() != nil {
		status["redis"] = "down" // degraded, still serving from Postgres
	}
	c.JSON(code, status)
}
