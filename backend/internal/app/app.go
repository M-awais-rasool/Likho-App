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
	"likho/backend/internal/geo"
	"likho/backend/internal/media"
	"likho/backend/internal/repository"
	"likho/backend/internal/service"
)

// Deps are the outside pieces the API is built from. Tests pass their own
// (a test database, an in-memory Redis, a fake Google).
type Deps struct {
	DB      *gorm.DB
	Redis   *redis.Client
	Catalog *catalog.Catalog // the content served at start (from ContentFS)
	Media   *media.Library   // pictures and recordings (nil: none)
	Google  service.GoogleVerifier
	Tokens  service.Tokens

	// Admin panel. ContentFS is the content the panel's levels are laid
	// over (default: the built-in content); Geo finds countries.
	ContentFS      fs.FS
	ContentOptions catalog.Options
	Geo            *geo.Resolver
	CountryHeader  string
	TrustedProxies []string
	AdminDir       string
	System         handler.SystemInfo
	Production     bool
}

// Built is the API with the services that run in the background.
type Built struct {
	Handler http.Handler
	Content *service.ContentService
	Admins  *service.AdminAuthService
}

// BuildApp wires everything together. Levels published in the admin panel
// are loaded from the database here (the start-up catalog is kept when
// they have problems).
func BuildApp(d Deps) *Built {
	repos := repository.New(d.DB)
	c := cache.New(d.Redis)
	if d.ContentFS == nil {
		d.ContentFS = content.FS
	}
	store := catalog.NewStore(d.Catalog)

	activity := service.NewActivityService(repos.Activity, repos.Admin, c, d.Geo)
	account := service.NewAccountService(repos.Accounts, repos.Children, c, activity)
	services := handler.Services{
		Auth:     service.NewAuthService(repos.Accounts, repos.Sessions, d.Google, d.Tokens, account, activity),
		Account:  account,
		Children: service.NewChildService(repos.Children, c, activity),
		Progress: service.NewProgressService(repos.Progress, store, c, activity),
		Room:     service.NewRoomService(repos.Room, c, activity),
		Courses:  service.NewCourseService(store),
	}
	content := service.NewContentService(d.ContentFS, d.ContentOptions, store, repos.Content, repos.Admin, repos.Insights)
	if rows, err := repos.Content.Levels(context.Background(), ""); err == nil && len(rows) > 0 {
		_ = content.Reload(context.Background())
	}
	health := &handler.HealthHandler{Postgres: database.Pinger(d.DB), Redis: c}
	admins := service.NewAdminAuthService(repos.Admin)
	adminHandler := &handler.AdminHandler{
		Auth: admins, Admin: service.NewAdminService(repos, store, c, activity, account), Content: content,
		Health: health, Info: d.System, Secure: d.Production,
	}
	handlers := handler.New(services, health)
	if d.Media == nil {
		d.Media, _ = media.Open("")
	}
	handlers.Media = &handler.MediaHandler{Library: d.Media}
	router := api.NewRouter(handlers, adminHandler, d.Tokens, c, api.Options{
		CountryHeader: d.CountryHeader, AdminDir: d.AdminDir, Seen: activity.Seen, TrustedProxies: d.TrustedProxies,
	})
	return &Built{Handler: router, Content: content, Admins: admins}
}

// LoadContent reads the learning content: built in, or from cfg.ContentDir.
func LoadContent(cfg config.Config) (*catalog.Catalog, error) {
	cat, err := catalog.Load(contentFS(cfg), catalog.Options{IncludeDrafts: cfg.ContentDrafts})
	if err != nil {
		return nil, err
	}
	for _, c := range cat.Courses() {
		slog.Info("course loaded", "id", c.Summary.ID, "levels", c.Stats.Levels, "version", c.Summary.Version, "draft", c.Draft)
	}
	return cat, nil
}

// OpenMedia indexes the pictures and recordings in cfg.MediaDir and logs
// the ones the content uses but the folder lacks (the app then shows a
// placeholder or uses the device voice; `content media-check` fails on them).
func OpenMedia(cfg config.Config, cat *catalog.Catalog) (*media.Library, error) {
	lib, err := media.Open(cfg.MediaDir)
	if err != nil {
		return nil, err
	}
	slog.Info("media indexed", "dir", cfg.MediaDir, "files", lib.Len(), "megabytes", lib.Bytes>>20, "version", lib.ETag)
	for _, c := range cat.Courses() {
		if missing := lib.Missing(c.MediaPaths()); len(missing) > 0 {
			slog.Warn("media missing", "course", c.Summary.ID, "count", len(missing), "first", missing[0])
		}
	}
	return lib, nil
}

func contentFS(cfg config.Config) fs.FS {
	if cfg.ContentDir != "" {
		return os.DirFS(cfg.ContentDir)
	}
	return content.FS
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
	lib, err := OpenMedia(cfg, cat)
	if err != nil {
		return err
	}
	db, err := database.Connect(ctx, cfg.DatabaseURL, !cfg.Production(), cfg.DBMaxConns)
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

	resolver := geo.Open(cfg.GeoIPDB)
	defer resolver.Close()
	built := BuildApp(Deps{
		DB: db, Redis: rdb, Catalog: cat, Media: lib, Google: google, Tokens: tokens,
		ContentFS: contentFS(cfg), ContentOptions: catalog.Options{IncludeDrafts: cfg.ContentDrafts},
		Geo: resolver, CountryHeader: cfg.CountryHeader, TrustedProxies: cfg.TrustedProxies, AdminDir: cfg.AdminDir, Production: cfg.Production(),
		System: handler.SystemInfo{Env: cfg.Env, StartedAt: time.Now(), GeoIP: resolver.Enabled(), CountryHeader: cfg.CountryHeader, DevLogin: cfg.DevLogin},
	})
	if err := built.Admins.Bootstrap(ctx, cfg.AdminBootstrapEmail, cfg.AdminBootstrapPassword); err != nil {
		return err
	}
	if cfg.AdminDir != "" {
		slog.Info("admin panel served", "url", "http://localhost:"+cfg.Port+"/admin/", "dir", cfg.AdminDir)
	}
	// other API servers may publish content: pick it up
	go built.Content.Watch(ctx, 15*time.Second)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           built.Handler,
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
