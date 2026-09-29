// Command api runs the Likho API (Go + Gin + Postgres/GORM + Redis).
//
//	go run ./cmd/api      (settings from the environment, see .env.example)
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"likho/backend/internal/app"
	"likho/backend/internal/config"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := app.Run(ctx, cfg); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
