// Package api is the HTTP API: every route in one place (router.go), the
// handlers behind them (handler/) and what runs around them (middleware/).
package api

import (
	"context"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/handler"
	"likho/backend/internal/api/middleware"
	"likho/backend/internal/cache"
	"likho/backend/internal/model"
	"likho/backend/internal/service"
)

// Limits per client (sign-in per IP, the rest per parent).
const (
	authPerMinute = 30
	apiPerMinute  = 600
	playPerMinute = 120
	maxBodyBytes  = 64 << 10

	adminLoginPerMinute = 10
)

// Options are the router's settings.
type Options struct {
	CountryHeader string // the CDN's country header (see middleware.ClientInfo)
	AdminDir      string // the admin panel's build, served at /admin/ ("" = not served)

	// TrustedProxies may set X-Forwarded-For (nginx); nobody else can.
	TrustedProxies []string

	// Seen is told about every signed-in request (activity tracking).
	Seen func(ctx context.Context, parentID string, info model.ClientInfo, force bool)
}

// NewRouter returns the API. Routes are versioned under /v1; see
// docs/openapi.yaml for the contract.
func NewRouter(h *handler.Handlers, admin *handler.AdminHandler, tokens service.Tokens, c *cache.Cache, opt Options) *gin.Engine {
	r := gin.New()
	r.HandleMethodNotAllowed = true
	// Gin believes every X-Forwarded-For by default: a client could send a
	// new fake IP with each request and never hit the per-IP limits
	if err := r.SetTrustedProxies(opt.TrustedProxies); err != nil {
		panic("TRUSTED_PROXIES: " + err.Error())
	}
	r.Use(middleware.Recovery(), middleware.RequestLog(), middleware.SecureHeaders(), middleware.BodyLimit(maxBodyBytes),
		middleware.ClientInfo(opt.CountryHeader))

	r.GET("/healthz", h.Health.Live)
	r.GET("/readyz", h.Health.Ready)

	v1 := r.Group("/v1")

	// public: the learning content, its pictures and recordings, and signing in
	v1.GET("/courses", h.Courses.List)
	v1.GET("/courses/:courseId", h.Courses.Get)
	if h.Media != nil {
		v1.GET("/media", h.Media.Manifest)
		r.GET("/media/*path", h.Media.File)
		r.HEAD("/media/*path", h.Media.File)
	}

	auth := v1.Group("/auth", middleware.RateLimit(c, "auth", authPerMinute, time.Minute))
	auth.POST("/google", h.Auth.GoogleSignIn) // the only way in: sign in = sign up
	auth.POST("/refresh", h.Auth.Refresh)

	// signed in
	in := v1.Group("", middleware.Auth(tokens), middleware.RateLimit(c, "api", apiPerMinute, time.Minute))
	if opt.Seen != nil {
		in.Use(middleware.Track(opt.Seen))
	}
	in.POST("/auth/logout", h.Auth.Logout)

	in.GET("/me", h.Account.Me)
	in.PATCH("/me/settings", h.Account.UpdateSettings)
	in.POST("/me/trial", h.Account.StartTrial)
	in.DELETE("/me", h.Account.Delete)

	in.POST("/children", h.Children.Create)
	in.PATCH("/children/:childId", h.Children.Update)
	in.DELETE("/children/:childId", h.Children.Delete)

	// playing: stars change here, so retries are made safe
	play := in.Group("/children/:childId",
		middleware.RateLimit(c, "play", playPerMinute, time.Minute),
		middleware.Idempotency(c),
	)
	play.POST("/courses/:courseId/results", h.Progress.Record)
	play.POST("/room/:itemId", h.Room.Tap)

	if admin != nil {
		adminRoutes(r, admin, c)
	}
	ui := adminUI(opt.AdminDir)
	r.NoRoute(func(c *gin.Context) {
		if ui != nil && (c.Request.Method == http.MethodGet || c.Request.Method == http.MethodHead) && (c.Request.URL.Path == "/admin" || strings.HasPrefix(c.Request.URL.Path, "/admin/")) &&
			!strings.HasPrefix(c.Request.URL.Path, "/admin/api/") {
			ui(c)
			return
		}
		c.JSON(http.StatusNotFound, gin.H{"error": "not_found", "message": "No such endpoint"})
	})
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{"error": "method_not_allowed", "message": "Method not allowed here"})
	})
	return r
}

// adminRoutes is the admin panel's API. Viewers can read everything;
// editors also change content and accounts; owners also manage the team
// and delete accounts.
func adminRoutes(r *gin.Engine, h *handler.AdminHandler, c *cache.Cache) {
	api := r.Group("/admin/api/v1")
	api.POST("/auth/login", middleware.RateLimit(c, "admin-login", adminLoginPerMinute, time.Minute), h.Login)
	api.POST("/auth/logout", h.Logout)

	in := api.Group("", middleware.AdminAuth(h.Auth.Session))
	in.GET("/auth/me", h.Me)
	in.POST("/auth/password", h.ChangePassword)

	in.GET("/courses", h.Courses)
	in.GET("/overview", h.Overview)
	in.GET("/families", h.Families)
	in.GET("/families.csv", h.FamiliesCSV)
	in.GET("/families/:parentId", h.Family)
	in.GET("/learners", h.Learners)
	in.GET("/levels/stats", h.LevelStats)
	in.GET("/activity", h.Activity)
	in.GET("/alerts", h.Alerts)
	in.GET("/alerts/unread", h.UnreadAlerts)
	in.POST("/alerts/read", h.ReadAlerts)
	in.GET("/settings/alerts", h.AlertRules)
	in.GET("/content/courses/:courseId", h.ContentCourse)
	in.GET("/content/courses/:courseId/document", h.ContentDocument)
	in.GET("/content/courses/:courseId/levels/:number", h.ContentLevel)
	in.POST("/content/courses/:courseId/levels/validate", h.ValidateLevel)
	in.GET("/audit", h.Audit)
	in.GET("/system", h.System)
	in.GET("/closed-test", h.ClosedTestBoard)

	edit := in.Group("", middleware.RequireRole(model.RoleEditor))
	edit.POST("/families/:parentId/plus", h.GrantPlus)
	edit.DELETE("/families/:parentId/plus", h.RevokePlus)
	edit.POST("/families/:parentId/sign-out", h.SignOut)
	edit.POST("/children/:childId/stars", h.AdjustStars)
	edit.PUT("/settings/alerts", h.SetAlertRules)
	edit.POST("/content/courses/:courseId/levels", h.SaveLevel)
	edit.PUT("/content/courses/:courseId/levels/:number", h.SaveLevel)
	edit.POST("/content/courses/:courseId/levels/:number/publish", h.LevelAction("publish"))
	edit.POST("/content/courses/:courseId/levels/:number/unpublish", h.LevelAction("unpublish"))
	edit.POST("/content/courses/:courseId/levels/:number/discard", h.LevelAction("discard"))
	edit.DELETE("/content/courses/:courseId/levels/:number", h.DeleteLevel)
	edit.POST("/content/courses/:courseId/worlds", h.SaveWorld)
	edit.PUT("/content/courses/:courseId/worlds/:folder", h.SaveWorld)
	edit.DELETE("/content/courses/:courseId/worlds/:folder", h.DeleteWorld)
	edit.PUT("/closed-test/settings", h.SetClosedTestSettings)
	edit.POST("/closed-test/testers", h.AddTesters)
	edit.PATCH("/closed-test/testers/:id", h.UpdateTester)
	edit.DELETE("/closed-test/testers/:id", h.DeleteTester)
	edit.PUT("/closed-test/accounts/:parentId", h.LinkTestAccount)
	edit.DELETE("/closed-test/accounts/:parentId", h.UnlinkTestAccount)

	own := in.Group("", middleware.RequireRole(model.RoleOwner))
	own.DELETE("/families/:parentId", h.DeleteFamily)
	own.GET("/team", h.Team)
	own.POST("/team", h.AddAdmin)
	own.PATCH("/team/:id", h.UpdateAdmin)
	own.DELETE("/team/:id", h.DeleteAdmin)
}

// adminUI serves the admin panel's build from [dir] at /admin/ (a single
// page app: unknown paths get index.html). nil when there is no build.
func adminUI(dir string) gin.HandlerFunc {
	if dir == "" {
		return nil
	}
	if _, err := os.Stat(filepath.Join(dir, "index.html")); err != nil {
		return nil
	}
	root := http.Dir(dir)
	return func(c *gin.Context) {
		p := strings.TrimPrefix(c.Request.URL.Path, "/admin")
		if p == "" {
			c.Redirect(http.StatusMovedPermanently, "/admin/")
			return
		}
		p = path.Clean(p)
		if fi, err := os.Stat(filepath.Join(dir, filepath.FromSlash(p))); err == nil && fi.IsDir() {
			p = path.Join(p, "index.html") // e.g. /preview/ (the phone preview)
		}
		f, err := root.Open(p)
		if err == nil {
			defer f.Close()
			if fi, err := f.Stat(); err == nil && !fi.IsDir() {
				if strings.HasPrefix(p, "/assets/") {
					c.Header("Cache-Control", "public, max-age=31536000, immutable") // hashed file names
				} else {
					c.Header("Cache-Control", "no-cache")
				}
				http.ServeContent(c.Writer, c.Request, fi.Name(), fi.ModTime(), f)
				return
			}
		}
		if strings.HasPrefix(p, "/preview/") || path.Ext(p) != "" {
			c.Status(http.StatusNotFound)
			return
		}
		c.Header("Cache-Control", "no-cache")
		c.File(filepath.Join(dir, "index.html"))
	}
}
