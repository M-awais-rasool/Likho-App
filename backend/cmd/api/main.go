// Likho API: Go + Gin + Postgres (GORM) + Redis.
//
// Start here. main wires everything together:
// config -> Postgres (+ tables) -> Redis -> course -> routes -> server.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/config"
	"likho/backend/database"
	"likho/backend/handlers"
	"likho/backend/repository"
	"likho/backend/routes"
	"likho/backend/services"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	if err := run(); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := database.Connect(ctx, cfg.DatabaseURL, !cfg.Production())
	if err != nil {
		return err
	}
	if err := database.Migrate(ctx, db); err != nil {
		return err
	}
	rdb, err := database.ConnectRedis(ctx, cfg.RedisURL)
	if err != nil {
		return err
	}
	defer rdb.Close()

	store := repository.New(db)
	course := services.NewCourse(store)
	if err := course.Import(ctx, cfg.CourseFile); err != nil {
		return err
	}
	if err := course.Reload(ctx); err != nil {
		slog.Warn("no course yet", "err", err) // /v1/course answers 503 until one is imported
	}
	go course.Watch(ctx, time.Minute)

	var google services.GoogleVerifier = services.NewGoogleIDTokens(cfg.GoogleClientIDs)
	if cfg.DevLogin {
		slog.Warn("DEV_LOGIN is on: \"dev:<email>\" is accepted as a Google token")
		google = services.DevGoogle{Next: google}
	}
	tokens := services.Tokens{Secret: cfg.JWTSecret, AccessTTL: cfg.AccessTTL, RefreshTTL: cfg.RefreshTTL}

	if cfg.Production() {
		gin.SetMode(gin.ReleaseMode)
	}
	h := &handlers.Handler{
		DB:     db,
		Redis:  rdb,
		Store:  store,
		Auth:   services.Auth{Store: store, Google: google, Tokens: tokens},
		Cache:  services.NewCache(rdb),
		Course: course,
	}
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           routes.New(h, tokens),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	errc := make(chan error, 1)
	go func() {
		slog.Info("listening", "port", cfg.Port, "env", cfg.Env)
		errc <- srv.ListenAndServe()
	}()
	select {
	case err := <-errc:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		slog.Info("shutting down")
	}
	// finish requests in flight, then close
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return err
	}
	if sqlDB, err := db.DB(); err == nil {
		sqlDB.Close()
	}
	return nil
}
