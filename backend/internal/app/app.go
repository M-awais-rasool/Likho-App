// Package app wires the API together (the composition root): config ->
// Postgres (+ tables) -> Redis -> content -> repositories -> services ->
// handlers -> router, and runs the HTTP server.
package app

import (
	"context"
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"

	"likho/backend/content"
	"likho/backend/internal/api"
	"likho/backend/internal/api/handler"
	"likho/backend/internal/cache"
	"likho/backend/internal/catalog"
	"likho/backend/internal/config"
	"likho/backend/internal/database"
	"likho/backend/internal/repository"
	"likho/backend/internal/service"
)

// Deps are the outside pieces the API is built from. Tests pass their own
// (a test database, an in-memory Redis, a fake Google).
type Deps struct {
	DB      *gorm.DB
	Redis   *redis.Client
	Catalog *catalog.Catalog
	Google  service.GoogleVerifier
	Tokens  service.Tokens
}

// Build returns the HTTP handler for [d].
func Build(d Deps) http.Handler {
	repos := repository.New(d.DB)
	c := cache.New(d.Redis)

	account := service.NewAccountService(repos.Accounts, repos.Children, c)
	services := handler.Services{
		Auth:     service.NewAuthService(repos.Accounts, repos.Sessions, d.Google, d.Tokens, account),
		Account:  account,
		Children: service.NewChildService(repos.Children, c),
		Progress: service.NewProgressService(repos.Progress, d.Catalog, c),
		Room:     service.NewRoomService(repos.Room, c),
		Courses:  service.NewCourseService(d.Catalog),
	}
	health := &handler.HealthHandler{Postgres: database.Pinger(d.DB), Redis: c}
	return api.NewRouter(handler.New(services, health), d.Tokens, c)
}

// LoadContent reads the learning content: built in, or from cfg.ContentDir.
func LoadContent(cfg config.Config) (*catalog.Catalog, error) {
	var fsys fs.FS = content.FS
	if cfg.ContentDir != "" {
		fsys = os.DirFS(cfg.ContentDir)
	}
	cat, err := catalog.Load(fsys, catalog.Options{IncludeDrafts: cfg.ContentDrafts})
	if err != nil {
		return nil, err
	}
	for _, c := range cat.Courses() {
		slog.Info("course loaded", "id", c.Summary.ID, "levels", c.Stats.Levels, "version", c.Summary.Version, "draft", c.Draft)
	}
	return cat, nil
}

// Run starts the API from [cfg] and serves until [ctx] ends, then finishes
// requests in flight and closes the connections.
func Run(ctx context.Context, cfg config.Config) error {
	if cfg.Production() {
		gin.SetMode(gin.ReleaseMode)
	}
	cat, err := LoadContent(cfg)
	if err != nil {
		return err
	}
	db, err := database.Connect(ctx, cfg.DatabaseURL, !cfg.Production())
	if err != nil {
		return err
	}
	defer database.Close(db)
	if err := database.Migrate(ctx, db); err != nil {
		return err
	}
	rdb, err := database.ConnectRedis(ctx, cfg.RedisURL)
	if err != nil {
		return err
	}
	defer rdb.Close()

	var google service.GoogleVerifier = service.NewGoogleIDTokens(cfg.GoogleClientIDs)
	if cfg.DevLogin {
		slog.Warn("DEV_LOGIN is on: \"dev:<email>\" is accepted as a Google token")
		google = service.DevGoogle{Next: google}
	}
	tokens := service.Tokens{Secret: cfg.JWTSecret, AccessTTL: cfg.AccessTTL, RefreshTTL: cfg.RefreshTTL}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           Build(Deps{DB: db, Redis: rdb, Catalog: cat, Google: google, Tokens: tokens}),
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
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}
