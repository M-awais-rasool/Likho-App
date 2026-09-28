package services

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// Cache keeps ready-made JSON answers in Redis. Redis is only an
// accelerator: if it is down, every method quietly misses and the handlers
// read Postgres instead.
type Cache struct {
	rdb *redis.Client
}

func NewCache(rdb *redis.Client) *Cache { return &Cache{rdb: rdb} }

const meTTL = 10 * time.Minute

func meKey(parentID string) string { return "me:" + parentID }

// Me returns the cached /v1/me JSON of a parent.
func (c *Cache) Me(ctx context.Context, parentID string) ([]byte, bool) {
	b, err := c.rdb.Get(ctx, meKey(parentID)).Bytes()
	if err != nil {
		if !errors.Is(err, redis.Nil) {
			slog.Warn("redis get", "err", err)
		}
		return nil, false
	}
	return b, true
}

func (c *Cache) SetMe(ctx context.Context, parentID string, body []byte) {
	if err := c.rdb.Set(ctx, meKey(parentID), body, meTTL).Err(); err != nil {
		slog.Warn("redis set", "err", err)
	}
}

// ForgetMe drops the cached account after any change to it.
func (c *Cache) ForgetMe(ctx context.Context, parentID string) {
	if err := c.rdb.Del(ctx, meKey(parentID)).Err(); err != nil {
		slog.Warn("redis del", "err", err)
	}
}

// Idempotency: a phone on a bad network may send "level finished" twice.
// The first answer is kept for a day under the client's Idempotency-Key and
// replayed, so stars are never awarded twice.

const (
	idemTTL     = 24 * time.Hour
	idemPending = "pending"
)

func idemKey(parentID, key string) string { return "idem:" + parentID + ":" + key }

// ClaimIdempotency: first = this request should run; otherwise [saved] is
// the earlier answer (empty while that request is still running).
func (c *Cache) ClaimIdempotency(ctx context.Context, parentID, key string) (first bool, saved []byte) {
	ok, err := c.rdb.SetNX(ctx, idemKey(parentID, key), idemPending, time.Minute).Result()
	if err != nil {
		slog.Warn("redis setnx", "err", err)
		return true, nil // Redis down: run it (the database still validates)
	}
	if ok {
		return true, nil
	}
	b, err := c.rdb.Get(ctx, idemKey(parentID, key)).Bytes()
	if err != nil || string(b) == idemPending {
		return false, nil
	}
	return false, b
}

func (c *Cache) SaveIdempotency(ctx context.Context, parentID, key string, body []byte) {
	if err := c.rdb.Set(ctx, idemKey(parentID, key), body, idemTTL).Err(); err != nil {
		slog.Warn("redis set", "err", err)
	}
}

// ReleaseIdempotency lets the client retry after a failed request.
func (c *Cache) ReleaseIdempotency(ctx context.Context, parentID, key string) {
	c.rdb.Del(ctx, idemKey(parentID, key))
}

// Allow is a fixed-window rate limit: at most [limit] hits per [window]
// for [key]. Fails open when Redis is down.
func (c *Cache) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration) {
	k := "rl:" + key + ":" + time.Now().Truncate(window).Format("150405")
	pipe := c.rdb.TxPipeline()
	incr := pipe.Incr(ctx, k)
	pipe.Expire(ctx, k, window)
	if _, err := pipe.Exec(ctx); err != nil {
		slog.Warn("redis rate limit", "err", err)
		return true, 0
	}
	if incr.Val() > int64(limit) {
		return false, time.Until(time.Now().Truncate(window).Add(window))
	}
	return true, 0
}
