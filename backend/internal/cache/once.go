package cache

import (
	"context"
	"log/slog"
	"time"
)

// FirstIn reports whether this is the first call for [key] in [ttl] (to do
// something at most once in a while, e.g. record that a parent was seen).
// When Redis is down it says yes: the work is done more often, never lost.
func (c *Cache) FirstIn(ctx context.Context, key string, ttl time.Duration) bool {
	ok, err := c.rdb.SetNX(ctx, "once:"+key, 1, ttl).Result()
	if err != nil {
		slog.Warn("redis setnx", "err", err)
		return true
	}
	return ok
}
