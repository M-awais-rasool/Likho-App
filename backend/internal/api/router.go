// Package routes lists every endpoint of the API in one place.
package routes

import (
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/handlers"
	"likho/backend/middleware"
	"likho/backend/services"
)

func New(h *handlers.Handler, tokens services.Tokens) *gin.Engine {
	r := gin.New()
	r.Use(middleware.Recovery(), middleware.RequestLog(), middleware.BodyLimit(64<<10))
	r.HandleMethodNotAllowed = true

	r.GET("/healthz", h.Health)
	r.GET("/readyz", h.Ready)

	v1 := r.Group("/v1")

	// public
	v1.GET("/course", h.GetCourse)
	auth := v1.Group("/auth", middleware.RateLimit(h.Cache, "auth", 30, time.Minute))
	auth.POST("/google", h.GoogleSignIn) // the only way in: sign in = sign up
	auth.POST("/refresh", h.Refresh)

	// signed in
	in := v1.Group("", middleware.Auth(tokens), middleware.RateLimit(h.Cache, "api", 600, time.Minute))
	in.POST("/auth/logout", h.Logout)

	in.GET("/me", h.Me)
	in.PATCH("/me/settings", h.UpdateSettings)
	in.POST("/me/trial", h.StartTrial)
	in.DELETE("/me", h.DeleteAccount)

	in.POST("/children", h.CreateChild)
	in.PATCH("/children/:id", h.UpdateChild)
	in.DELETE("/children/:id", h.DeleteChild)

	play := in.Group("/children/:id", middleware.RateLimit(h.Cache, "play", 120, time.Minute))
	play.POST("/results", h.RecordResult)
	play.POST("/room/:item", h.TapItem)

	r.NoRoute(func(c *gin.Context) { c.JSON(404, gin.H{"error": "not_found", "message": "No such endpoint"}) })
	return r
}
