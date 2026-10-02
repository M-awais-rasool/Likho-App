// Package cache keeps short-lived data in Redis: ready-made /v1/me answers,
// idempotent replies and rate-limit counters.
//
// Redis is only an accelerator. When it is slow or down every method
// quietly misses (or allows) and the API keeps working from Postgres.
package cache

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

type Cache struct {
	rdb *redis.Client
}

func New(rdb *redis.Client) *Cache { return &Cache{rdb: rdb} }

// Ping reports whether Redis answers (readiness check).
func (c *Cache) Ping(ctx context.Context) error { return c.rdb.Ping(ctx).Err() }

// Keys carry a version: when the JSON shape changes, a deploy starts with an
// empty cache instead of serving the old shape.
const (
	meTTL    = 10 * time.Minute
	mePrefix = "me:v3:" // v3: children have a class
)

// Me returns the cached /v1/me JSON of a parent.
func (c *Cache) Me(ctx context.Context, parentID string) ([]byte, bool) {
	b, err := c.rdb.Get(ctx, mePrefix+parentID).Bytes()
	if err != nil {
		if !errors.Is(err, redis.Nil) {
			slog.Warn("redis get", "err", err)
		}
		return nil, false
	}
	return b, true
}

func (c *Cache) SetMe(ctx context.Context, parentID string, body []byte) {
	if err := c.rdb.Set(ctx, mePrefix+parentID, body, meTTL).Err(); err != nil {
		slog.Warn("redis set", "err", err)
	}
}

// ForgetMe drops the cached account after any change to it.
func (c *Cache) ForgetMe(ctx context.Context, parentID string) {
	if err := c.rdb.Del(ctx, mePrefix+parentID).Err(); err != nil {
		slog.Warn("redis del", "err", err)
	}
}
