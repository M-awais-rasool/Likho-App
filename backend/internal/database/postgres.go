// Package database opens Postgres through GORM (the source of truth) and
// Redis (the accelerator: cache, rate limits, idempotency).
package database

import (
	"context"
	"fmt"
	"log/slog"
	"runtime"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"likho/backend/models"
)

// Connect opens Postgres with settings chosen for speed:
//   - PrepareStmt: every query is prepared once per connection and reused
//   - SkipDefaultTransaction: single writes are not wrapped in a transaction
//   - a connection pool sized for the CPU, idle connections recycled
//   - only slow queries (> 200 ms) and errors are logged
func Connect(ctx context.Context, url string, debug bool) (*gorm.DB, error) {
	level := logger.Warn
	if debug {
		level = logger.Info
	}
	db, err := gorm.Open(postgres.Open(url), &gorm.Config{
		PrepareStmt:            true,
		SkipDefaultTransaction: true,
		TranslateError:         true, // unique violations become gorm.ErrDuplicatedKey
		NowFunc:                func() time.Time { return time.Now().UTC() },
		Logger: logger.New(slogWriter{}, logger.Config{
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
	sqlDB.SetMaxOpenConns(max(8, runtime.NumCPU()*4))
	sqlDB.SetMaxIdleConns(max(4, runtime.NumCPU()*2))
	sqlDB.SetConnMaxIdleTime(5 * time.Minute)
	sqlDB.SetConnMaxLifetime(time.Hour)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := sqlDB.PingContext(pingCtx); err != nil {
		return nil, fmt.Errorf("postgres ping: %w", err)
	}
	return db, nil
}

// Migrate creates or updates every table from models.Tables. A Postgres
// advisory lock keeps two servers starting together from racing.
func Migrate(ctx context.Context, db *gorm.DB) error {
	return db.WithContext(ctx).Connection(func(conn *gorm.DB) error {
		const lockID = 42421001
		if err := conn.Exec("SELECT pg_advisory_lock(?)", lockID).Error; err != nil {
			return err
		}
		defer conn.Exec("SELECT pg_advisory_unlock(?)", lockID)
		return conn.AutoMigrate(models.Tables...)
	})
}

// slogWriter sends GORM's log lines to the app's structured log.
type slogWriter struct{}

func (slogWriter) Printf(format string, args ...any) {
	slog.Warn(fmt.Sprintf(format, args...), "source", "gorm")
}
