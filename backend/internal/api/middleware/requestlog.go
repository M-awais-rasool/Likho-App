// Package middleware runs before the handlers: logging, auth, rate limits.
package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/services"
)

// Context keys set by Auth.
const (
	ParentIDKey  = "parentID"
	SessionIDKey = "sessionID"
)

// RequestLog gives each request an id (X-Request-ID) and logs one line when
// it ends. Health checks are not logged.
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
			"parent", c.GetString(ParentIDKey),
		)
	}
}

// BodyLimit rejects request bodies larger than [n] bytes.
func BodyLimit(n int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, n)
		c.Next()
	}
}

// Auth accepts "Authorization: Bearer <access token>". The token is checked
// by its signature alone (no database), so this costs microseconds.
func Auth(tokens services.Tokens) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer ")
		if !ok {
			abort(c, http.StatusUnauthorized, "unauthorized", "Sign in with Google first")
			return
		}
		claims, err := tokens.ParseAccess(strings.TrimSpace(raw))
		if err != nil {
			abort(c, http.StatusUnauthorized, "token_expired", "Access token is invalid or expired; refresh it")
			return
		}
		c.Set(ParentIDKey, claims.Subject)
		c.Set(SessionIDKey, claims.SessionID)
		c.Next()
	}
}

// RateLimit allows [limit] requests per [window] per signed-in parent (or
// per IP before sign-in).
func RateLimit(cache *services.Cache, name string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		who := c.GetString(ParentIDKey)
		if who == "" {
			who = "ip:" + c.ClientIP()
		}
		ok, retry := cache.Allow(c.Request.Context(), name+":"+who, limit, window)
		if !ok {
			c.Header("Retry-After", strconv.Itoa(int(retry.Seconds())+1))
			abort(c, http.StatusTooManyRequests, "rate_limited", "Too many requests, try again shortly")
			return
		}
		c.Next()
	}
}

// Recovery turns a panic into a JSON 500 (and logs it).
func Recovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, err any) {
		slog.Error("panic", "err", err, "path", c.FullPath())
		abort(c, http.StatusInternalServerError, "internal", "Something went wrong")
	})
}

func abort(c *gin.Context, status int, code, msg string) {
	c.AbortWithStatusJSON(status, gin.H{"error": code, "message": msg})
}
