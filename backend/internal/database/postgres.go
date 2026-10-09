// Package database opens Postgres through GORM (the source of truth: tables
// from internal/model) and Redis (the accelerator: cache, rate limits,
// idempotency).
package database

import (
	"context"
	"fmt"
	"log/slog"
	"runtime"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"likho/backend/internal/model"
)

// Connect opens Postgres with settings chosen for speed:
//   - PrepareStmt: every query is prepared once per connection and reused
//   - SkipDefaultTransaction: single writes are not wrapped in a transaction
//   - a pool of at most [maxConns] connections (0 = by the number of CPUs,
//     8 to 20, so the API shares the database server politely), idle
//     connections recycled
//   - only slow queries (> 200 ms) and errors are logged
//
// Every connection runs in UTC. A day in the app is a UTC day (active_days,
// play_days, the week from Monday), so current_date and date casts in SQL
// must count the same days, whatever time zone the database server (or
// PGTZ) is set to.
func Connect(ctx context.Context, url string, debug bool, maxConns int) (*gorm.DB, error) {
	level, out := logger.Warn, slogWriter{slog.LevelWarn}
	if debug {
		level, out = logger.Info, slogWriter{slog.LevelInfo} // every query, for development
	}
	cfg, err := pgx.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("postgres: %w", err)
	}
	cfg.RuntimeParams["timezone"] = "UTC"
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: stdlib.OpenDB(*cfg)}), &gorm.Config{
		PrepareStmt:            true,
		SkipDefaultTransaction: true,
		TranslateError:         true, // unique violations become gorm.ErrDuplicatedKey
		NowFunc:                func() time.Time { return time.Now().UTC() },
		Logger: logger.New(out, logger.Config{
			SlowThreshold:             200 * time.Millisecond,
			LogLevel:                  level,
			IgnoreRecordNotFoundError: true,
		}),
	})
	if err != nil {
		return nil, fmt.Errorf("postgres: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	if maxConns <= 0 {
		maxConns = min(20, max(8, runtime.NumCPU()*4))
	}
	sqlDB.SetMaxOpenConns(maxConns)
	sqlDB.SetMaxIdleConns(max(2, maxConns/2))
	sqlDB.SetConnMaxIdleTime(5 * time.Minute)
	sqlDB.SetConnMaxLifetime(time.Hour)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := sqlDB.PingContext(pingCtx); err != nil {
		return nil, fmt.Errorf("postgres ping: %w", err)
	}
	return db, nil
}

// Migrate creates or updates every table from model.Tables. A Postgres
// advisory lock keeps two servers starting together from racing.
func Migrate(ctx context.Context, db *gorm.DB) error {
	return db.WithContext(ctx).Connection(func(conn *gorm.DB) error {
		const lockID = 42421001
		if err := conn.Exec("SELECT pg_advisory_lock(?)", lockID).Error; err != nil {
			return err
		}
		defer conn.Exec("SELECT pg_advisory_unlock(?)", lockID)
		return conn.AutoMigrate(model.Tables...)
	})
}

// slogWriter sends GORM's log lines to the app's structured log.
type slogWriter struct{ level slog.Level }

func (w slogWriter) Printf(format string, args ...any) {
	slog.Log(context.Background(), w.level, fmt.Sprintf(format, args...), "source", "gorm")
}

// Pinger reports whether Postgres answers (readiness check).
func Pinger(db *gorm.DB) interface{ Ping(context.Context) error } { return sqlPinger{db} }

type sqlPinger struct{ db *gorm.DB }

func (p sqlPinger) Ping(ctx context.Context) error {
	sqlDB, err := p.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.PingContext(ctx)
}

// Close closes the connection pool.
func Close(db *gorm.DB) {
	if sqlDB, err := db.DB(); err == nil {
		_ = sqlDB.Close()
	}
}
