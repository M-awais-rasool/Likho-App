// Package middleware runs around the handlers: request ids and logging,
// panics, body size, auth, rate limits and idempotent retries.
package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestLog gives each request an id (X-Request-ID, kept when the client
// sends one) and logs one line when it ends. Health checks are not logged.
func RequestLog() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader("X-Request-ID")
		if id == "" || len(id) > 64 {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		c.Header("X-Request-ID", id)
		start := time.Now()
		c.Next()
		if c.FullPath() == "/healthz" {
			return
		}
		level := slog.LevelInfo
		if c.Writer.Status() >= 500 {
			level = slog.LevelError
		}
		slog.Log(c.Request.Context(), level, "request",
			"id", id,
			"method", c.Request.Method,
			"path", c.FullPath(),
			"status", c.Writer.Status(),
			"ms", float64(time.Since(start).Microseconds())/1000,
			"ip", c.ClientIP(),
			"parent", ParentID(c),
		)
	}
}
