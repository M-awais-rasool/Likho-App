package cache

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"
)

// Idempotency: a phone on a bad network may send "level finished" twice.
// The first answer is kept for a day under the client's Idempotency-Key and
// replayed, so a retry never counts twice.

const (
	idemTTL     = 24 * time.Hour
	idemRunning = time.Minute // how long a request may hold its key
	idemPending = "pending"
)

// Reply is a stored answer.
type Reply struct {
	Status int    `json:"s"`
	Body   []byte `json:"b"`
}

func idemKey(scope, key string) string { return "idem:v1:" + scope + ":" + key }

// Claim reserves [key]: first = this request should run. Otherwise [saved]
// is the earlier answer, or nil while that request is still running.
func (c *Cache) Claim(ctx context.Context, scope, key string) (first bool, saved *Reply) {
	ok, err := c.rdb.SetNX(ctx, idemKey(scope, key), idemPending, idemRunning).Result()
	if err != nil {
		slog.Warn("redis setnx", "err", err)
		return true, nil // Redis down: run it (the database still enforces the rules)
	}
	if ok {
		return true, nil
	}
	b, err := c.rdb.Get(ctx, idemKey(scope, key)).Bytes()
	if err != nil || string(b) == idemPending {
		return false, nil
	}
	var r Reply
	if json.Unmarshal(b, &r) != nil {
		return false, nil
	}
	return false, &r
}

// Save keeps the answer for replays.
func (c *Cache) Save(ctx context.Context, scope, key string, r Reply) {
	b, _ := json.Marshal(r)
	if err := c.rdb.Set(ctx, idemKey(scope, key), b, idemTTL).Err(); err != nil {
		slog.Warn("redis set", "err", err)
	}
}

// Release lets the client retry after a failed request.
func (c *Cache) Release(ctx context.Context, scope, key string) {
	c.rdb.Del(ctx, idemKey(scope, key))
}
