// Package handler is the HTTP layer: read the request, call a service,
// write JSON. No SQL and no business rules here.
package handler

import (
	"encoding/json"
	"net/http"
	"regexp"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/middleware"
	"likho/backend/internal/domain"
	"likho/backend/internal/service"
)

// Services the handlers call.
type Services struct {
	Auth     *service.AuthService
	Account  *service.AccountService
	Children *service.ChildService
	Progress *service.ProgressService
	Room     *service.RoomService
	Courses  *service.CourseService
	Billing  *service.BillingService
}

// Handlers groups one handler per resource; the router maps URLs to them.
type Handlers struct {
	Auth     *AuthHandler
	Account  *AccountHandler
	Children *ChildHandler
	Progress *ProgressHandler
	Room     *RoomHandler
	Courses  *CourseHandler
	Billing  *BillingHandler
	Health   *HealthHandler
	Media    *MediaHandler
}

func New(s Services, health *HealthHandler) *Handlers {
	return &Handlers{
		Auth:     &AuthHandler{auth: s.Auth},
		Account:  &AccountHandler{account: s.Account},
		Children: &ChildHandler{children: s.Children},
		Progress: &ProgressHandler{progress: s.Progress},
		Room:     &RoomHandler{room: s.Room},
		Courses:  &CourseHandler{courses: s.Courses},
		Billing:  &BillingHandler{billing: s.Billing},
		Health:   health,
	}
}

// bind reads a JSON body into [v]; false (and a 400) when it is not valid.
func bind(c *gin.Context, v any) bool {
	if err := json.NewDecoder(c.Request.Body).Decode(v); err != nil {
		writeError(c, domain.Invalid("body must be valid JSON"))
		return false
	}
	return true
}

var (
	uuidRe = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	slugRe = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
)

// childID reads :childId; an id that is not a UUID is simply not found.
func childID(c *gin.Context) (string, bool) {
	id := c.Param("childId")
	if !uuidRe.MatchString(id) {
		writeError(c, domain.ErrNotFound)
		return "", false
	}
	return id, true
}

// courseID reads :courseId.
func courseID(c *gin.Context) (string, bool) {
	id := c.Param("courseId")
	if len(id) > 64 || !slugRe.MatchString(id) {
		writeError(c, domain.ErrCourseNotFound)
		return "", false
	}
	return id, true
}

func parentID(c *gin.Context) string { return middleware.ParentID(c) }

func writeJSON(c *gin.Context, status int, v any) { c.JSON(status, v) }

func noContent(c *gin.Context) { c.Status(http.StatusNoContent) }
