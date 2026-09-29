package middleware

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// Limiter counts requests (cache.Cache in production).
type Limiter interface {
	Allow(ctx context.Context, key string, limit int, window time.Duration) (ok bool, retry time.Duration)
}

// RateLimit allows [limit] requests per [window] per signed-in parent (or
// per IP before sign-in), counted separately for each [name].
func RateLimit(l Limiter, name string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		who := ParentID(c)
		if who == "" {
			who = "ip:" + c.ClientIP()
		}
		ok, retry := l.Allow(c.Request.Context(), name+":"+who, limit, window)
		if !ok {
			c.Header("Retry-After", strconv.Itoa(int(retry.Seconds())+1))
			abort(c, http.StatusTooManyRequests, "rate_limited", "Too many requests, try again shortly")
			return
		}
		c.Next()
	}
}
