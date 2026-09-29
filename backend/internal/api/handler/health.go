package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Pinger is something the API depends on (Postgres, Redis).
type Pinger interface {
	Ping(ctx context.Context) error
}

type HealthHandler struct {
	Postgres Pinger
	Redis    Pinger
}

// Live: GET /healthz -> the process is up (for the load balancer).
func (h *HealthHandler) Live(c *gin.Context) { writeJSON(c, http.StatusOK, gin.H{"ok": true}) }

// Ready: GET /readyz -> Postgres answers (503 if not). Redis being down is
// reported but still ready: the API works without it, only slower.
func (h *HealthHandler) Ready(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	status := gin.H{"postgres": "ok", "redis": "ok"}
	code := http.StatusOK
	if h.Postgres.Ping(ctx) != nil {
		status["postgres"], code = "down", http.StatusServiceUnavailable
	}
	if h.Redis.Ping(ctx) != nil {
		status["redis"] = "down"
	}
	writeJSON(c, code, status)
}
