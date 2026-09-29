package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/service"
)

// Context keys set by Auth.
const (
	parentIDKey  = "parentID"
	sessionIDKey = "sessionID"
)

// ParentID is the signed-in parent ("" before sign-in).
func ParentID(c *gin.Context) string { return c.GetString(parentIDKey) }

// SessionID is the signed-in device.
func SessionID(c *gin.Context) string { return c.GetString(sessionIDKey) }

// Auth accepts "Authorization: Bearer <access token>". The token is checked
// by its signature alone (no database), so this costs microseconds.
func Auth(tokens service.Tokens) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer ")
		if !ok {
			abort(c, http.StatusUnauthorized, "unauthorized", "Sign in with Google first")
			return
		}
		claims, err := tokens.ParseAccess(strings.TrimSpace(raw))
		if err != nil {
			abort(c, http.StatusUnauthorized, "token_expired", "Access token is invalid or expired; refresh it")
			return
		}
		c.Set(parentIDKey, claims.Subject)
		c.Set(sessionIDKey, claims.SessionID)
		c.Next()
	}
}
