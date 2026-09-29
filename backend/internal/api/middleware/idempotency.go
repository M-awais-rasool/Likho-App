package middleware

import (
	"bytes"
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/cache"
)

// IdempotencyStore keeps first answers (cache.Cache in production).
type IdempotencyStore interface {
	Claim(ctx context.Context, scope, key string) (first bool, saved *cache.Reply)
	Save(ctx context.Context, scope, key string, r cache.Reply)
	Release(ctx context.Context, scope, key string)
}

const maxIdempotencyKey = 100

// Idempotency makes retries safe: a request sent again with the same
// "Idempotency-Key" header gets the first answer again (with
// "Idempotent-Replay: true") instead of running twice. Keys are per parent
// and per URL. A failed request frees its key so the client can retry.
func Idempotency(store IdempotencyStore) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := c.GetHeader("Idempotency-Key")
		if key == "" {
			c.Next()
			return
		}
		if len(key) > maxIdempotencyKey {
			abort(c, http.StatusBadRequest, "invalid_input", "Idempotency-Key is too long")
			return
		}
		ctx := c.Request.Context()
		scope := ParentID(c) + ":" + c.Request.Method + ":" + c.Request.URL.Path
		first, saved := store.Claim(ctx, scope, key)
		if !first {
			if saved == nil {
				abort(c, http.StatusConflict, "in_progress", "The same request is still running")
				return
			}
			c.Header("Idempotent-Replay", "true")
			c.Data(saved.Status, "application/json; charset=utf-8", saved.Body)
			c.Abort()
			return
		}

		rec := &recorder{ResponseWriter: c.Writer}
		c.Writer = rec
		c.Next()
		if status := rec.Status(); status >= 200 && status < 300 {
			store.Save(ctx, scope, key, cache.Reply{Status: status, Body: rec.body.Bytes()})
		} else {
			store.Release(ctx, scope, key)
		}
	}
}

// recorder keeps a copy of the response body.
type recorder struct {
	gin.ResponseWriter
	body bytes.Buffer
}

func (r *recorder) Write(b []byte) (int, error) {
	r.body.Write(b)
	return r.ResponseWriter.Write(b)
}

func (r *recorder) WriteString(s string) (int, error) {
	r.body.WriteString(s)
	return r.ResponseWriter.WriteString(s)
}
