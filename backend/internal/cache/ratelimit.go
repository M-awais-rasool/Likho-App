package cache

import (
	"context"
	"log/slog"
	"time"
)

// Allow is a fixed-window rate limit: at most [limit] hits per [window] for
// [key]. It fails open when Redis is down. retry = when the window resets.
func (c *Cache) Allow(ctx context.Context, key string, limit int, window time.Duration) (ok bool, retry time.Duration) {
	start := time.Now().Truncate(window)
	k := "rl:" + key + ":" + start.Format("150405")
	pipe := c.rdb.TxPipeline()
	incr := pipe.Incr(ctx, k)
	pipe.Expire(ctx, k, window)
	if _, err := pipe.Exec(ctx); err != nil {
		slog.Warn("redis rate limit", "err", err)
		return true, 0
	}
	if incr.Val() > int64(limit) {
		return false, time.Until(start.Add(window))
	}
	return true, 0
}
