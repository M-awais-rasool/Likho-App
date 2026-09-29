package middleware

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Recovery turns a panic into a JSON 500 (and logs it).
func Recovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, err any) {
		slog.Error("panic", "err", err, "path", c.FullPath())
		abort(c, http.StatusInternalServerError, "internal", "Something went wrong")
	})
}

// BodyLimit rejects request bodies larger than [n] bytes.
func BodyLimit(n int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, n)
		c.Next()
	}
}

// SecureHeaders: JSON only, never sniffed, never cached by proxies unless
// the handler says so.
func SecureHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.Writer.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Cache-Control", "no-store")
		c.Next()
	}
}

// abort answers {"error": code, "message": msg}, the API's error shape.
func abort(c *gin.Context, status int, code, msg string) {
	c.AbortWithStatusJSON(status, gin.H{"error": code, "message": msg})
}
