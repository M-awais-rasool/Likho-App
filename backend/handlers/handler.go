// Package handlers is the HTTP layer: read the request, check it, call the
// repository or a service, answer JSON. No SQL and no business rules here.
package handlers

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"regexp"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"

	"likho/backend/middleware"
	"likho/backend/repository"
	"likho/backend/services"
)

type Handler struct {
	DB     *gorm.DB
	Redis  *redis.Client
	Store  *repository.Store
	Auth   services.Auth
	Cache  *services.Cache
	Course *services.Course
}

// Error answer: {"error": "<code>", "message": "<text>"}.
func fail(c *gin.Context, status int, code, msg string) {
	c.AbortWithStatusJSON(status, gin.H{"error": code, "message": msg})
}

func badInput(c *gin.Context, msg string) { fail(c, http.StatusBadRequest, "invalid_input", msg) }

// failErr maps repository / service errors to HTTP answers.
func failErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		fail(c, http.StatusNotFound, "not_found", "Not found")
	case errors.Is(err, repository.ErrTooManyChildren):
		fail(c, http.StatusConflict, "too_many_children", "A family can have up to 4 children")
	case errors.Is(err, repository.ErrLastChild):
		fail(c, http.StatusConflict, "last_child", "The only child profile cannot be deleted")
	case errors.Is(err, repository.ErrLevelLocked):
		fail(c, http.StatusConflict, "level_locked", "Finish the level before this one first")
	case errors.Is(err, repository.ErrPlusRequired):
		fail(c, http.StatusPaymentRequired, "plus_required", "This level needs Likho Plus")
	case errors.Is(err, repository.ErrNotEnoughStars):
		fail(c, http.StatusConflict, "not_enough_stars", "Not enough stars for this item")
	case errors.Is(err, repository.ErrUnknownItem):
		fail(c, http.StatusNotFound, "unknown_item", "No such item in the shop")
	case errors.Is(err, repository.ErrTrialUsed):
		fail(c, http.StatusConflict, "trial_used", "The free trial was already used")
	case errors.Is(err, repository.ErrSessionInvalid):
		fail(c, http.StatusUnauthorized, "session_invalid", "Sign in with Google again")
	case errors.Is(err, repository.ErrSessionReused):
		fail(c, http.StatusUnauthorized, "session_reused", "Signed out on all devices for safety; sign in again")
	case errors.Is(err, services.ErrBadGoogleToken):
		fail(c, http.StatusUnauthorized, "invalid_google_token", "Google sign-in could not be verified")
	default:
		slog.Error("request failed", "path", c.FullPath(), "err", err)
		fail(c, http.StatusInternalServerError, "internal", "Something went wrong")
	}
}

// bind reads a JSON body into [v]; false (and a 400) when it is not valid.
func bind(c *gin.Context, v any) bool {
	if err := json.NewDecoder(c.Request.Body).Decode(v); err != nil {
		badInput(c, "Body must be valid JSON")
		return false
	}
	return true
}

func parentID(c *gin.Context) string { return c.GetString(middleware.ParentIDKey) }

var uuidRe = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// childID reads :id; an id that is not a UUID is simply not found.
func childID(c *gin.Context) (string, bool) {
	id := c.Param("id")
	if !uuidRe.MatchString(id) {
		fail(c, http.StatusNotFound, "not_found", "Not found")
		return "", false
	}
	return id, true
}
