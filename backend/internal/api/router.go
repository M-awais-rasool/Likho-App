// Package api is the HTTP API: every route in one place (router.go), the
// handlers behind them (handler/) and what runs around them (middleware/).
package api

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/handler"
	"likho/backend/internal/api/middleware"
	"likho/backend/internal/cache"
	"likho/backend/internal/service"
)

// Limits per client (sign-in per IP, the rest per parent).
const (
	authPerMinute = 30
	apiPerMinute  = 600
	playPerMinute = 120
	maxBodyBytes  = 64 << 10
)

// NewRouter returns the API. Routes are versioned under /v1; see
// docs/openapi.yaml for the contract.
func NewRouter(h *handler.Handlers, tokens service.Tokens, c *cache.Cache) *gin.Engine {
	r := gin.New()
	r.HandleMethodNotAllowed = true
	r.Use(middleware.Recovery(), middleware.RequestLog(), middleware.SecureHeaders(), middleware.BodyLimit(maxBodyBytes))

	r.GET("/healthz", h.Health.Live)
	r.GET("/readyz", h.Health.Ready)

	v1 := r.Group("/v1")

	// public: the learning content and signing in
	v1.GET("/courses", h.Courses.List)
	v1.GET("/courses/:courseId", h.Courses.Get)

	auth := v1.Group("/auth", middleware.RateLimit(c, "auth", authPerMinute, time.Minute))
	auth.POST("/google", h.Auth.GoogleSignIn) // the only way in: sign in = sign up
	auth.POST("/refresh", h.Auth.Refresh)

	// signed in
	in := v1.Group("", middleware.Auth(tokens), middleware.RateLimit(c, "api", apiPerMinute, time.Minute))
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

	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"error": "not_found", "message": "No such endpoint"})
	})
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{"error": "method_not_allowed", "message": "Method not allowed here"})
	})
	return r
}
