package middleware

import (
	"context"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/domain"
	"likho/backend/internal/service"
)

// AdminCookie holds the admin panel session (HttpOnly, SameSite=Strict,
// path /admin).
const AdminCookie = "likho_admin"

const adminKey = "admin"

// Admin is the signed-in admin (zero before AdminAuth).
func Admin(c *gin.Context) service.AdminView {
	a, _ := c.Get(adminKey)
	v, _ := a.(service.AdminView)
	return v
}

// AdminAuth lets only signed-in admins through. Changes must also carry
// the X-Requested-With: likho-admin header, which a page on another site
// cannot send without the browser asking first (CSRF protection on top of
// the SameSite cookie).
func AdminAuth(session func(ctx context.Context, token string) (service.AdminView, error)) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method != http.MethodGet && c.Request.Method != http.MethodHead && c.GetHeader("X-Requested-With") != "likho-admin" {
			abort(c, http.StatusForbidden, "csrf", "Missing X-Requested-With header")
			return
		}
		token, _ := c.Cookie(AdminCookie)
		a, err := session(c.Request.Context(), token)
		if err != nil {
			var de *domain.Error
			if errors.As(err, &de) && de.Kind == domain.KindUnauthorized {
				abort(c, http.StatusUnauthorized, de.Code, de.Message)
				return
			}
			abort(c, http.StatusInternalServerError, "internal", "Something went wrong")
			return
		}
		c.Set(adminKey, a)
		c.Next()
	}
}

// RequireRole lets only admins with at least [role] through.
func RequireRole(role string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !service.RoleAtLeast(Admin(c).Role, role) {
			abort(c, http.StatusForbidden, domain.ErrAdminForbidden.Code, domain.ErrAdminForbidden.Message)
			return
		}
		c.Next()
	}
}
