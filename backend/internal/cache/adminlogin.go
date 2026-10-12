package cache

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// Signing in to the admin panel is two steps (password, then the
// authenticator code); between them the server keeps a short-lived ticket.
// It also counts wrong tries per account (a lock that holds whatever the
// IP).

func ticketKey(id string) string  { return "adminlogin:v1:" + id }
func failKey(email string) string { return "adminfail:v1:" + email }

// PutLoginTicket keeps [v] under [id] for [ttl].
func (c *Cache) PutLoginTicket(ctx context.Context, id string, v []byte, ttl time.Duration) error {
	return c.rdb.Set(ctx, ticketKey(id), v, ttl).Err()
}

// LoginTicket is the ticket [id]; false when unknown or expired.
func (c *Cache) LoginTicket(ctx context.Context, id string) ([]byte, bool, error) {
	v, err := c.rdb.Get(ctx, ticketKey(id)).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, false, nil
	}
	return v, err == nil, err
}

func (c *Cache) DropLoginTicket(ctx context.Context, id string) {
	if err := c.rdb.Del(ctx, ticketKey(id)).Err(); err != nil {
		slog.Warn("redis del", "err", err)
	}
}

// LoginFailures is the number of wrong tries for [email] lately (0 when
// Redis is down: the per-IP limits still hold).
func (c *Cache) LoginFailures(ctx context.Context, email string) int64 {
	n, err := c.rdb.Get(ctx, failKey(email)).Int64()
	if err != nil && !errors.Is(err, redis.Nil) {
		slog.Warn("redis get", "err", err)
	}
	return n
}

// AddLoginFailure counts a wrong try; the count is forgotten [window]
// after the last one.
func (c *Cache) AddLoginFailure(ctx context.Context, email string, window time.Duration) int64 {
	pipe := c.rdb.TxPipeline()
	incr := pipe.Incr(ctx, failKey(email))
	pipe.Expire(ctx, failKey(email), window)
	if _, err := pipe.Exec(ctx); err != nil {
		slog.Warn("redis incr", "err", err)
		return 0
	}
	return incr.Val()
}

func (c *Cache) ClearLoginFailures(ctx context.Context, email string) {
	if err := c.rdb.Del(ctx, failKey(email)).Err(); err != nil {
		slog.Warn("redis del", "err", err)
	}
}
