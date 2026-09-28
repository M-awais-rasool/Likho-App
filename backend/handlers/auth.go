package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/middleware"
)

// GoogleSignIn: POST /v1/auth/google {"idToken": "..."}
// The only way in. Existing account -> continues; new Google account ->
// a new Likho account is created. Answers tokens + the whole account.
func (h *Handler) GoogleSignIn(c *gin.Context) {
	var in struct {
		IDToken string `json:"idToken"`
		Device  string `json:"device"`
	}
	if !bind(c, &in) {
		return
	}
	if strings.TrimSpace(in.IDToken) == "" {
		badInput(c, "idToken is required")
		return
	}
	device := in.Device
	if device == "" {
		device = c.GetHeader("User-Agent")
	}
	out, err := h.Auth.SignInWithGoogle(c.Request.Context(), in.IDToken, truncate(device, 120))
	if err != nil {
		failErr(c, err)
		return
	}
	status := http.StatusOK
	if out.IsNewAccount {
		status = http.StatusCreated
	}
	c.JSON(status, out)
}

// Refresh: POST /v1/auth/refresh {"refreshToken": "..."} -> a new token pair.
func (h *Handler) Refresh(c *gin.Context) {
	var in struct {
		RefreshToken string `json:"refreshToken"`
	}
	if !bind(c, &in) {
		return
	}
	if in.RefreshToken == "" {
		badInput(c, "refreshToken is required")
		return
	}
	out, err := h.Auth.Refresh(c.Request.Context(), in.RefreshToken)
	if err != nil {
		failErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

// Logout: POST /v1/auth/logout (signed in) -> this device is signed out.
func (h *Handler) Logout(c *gin.Context) {
	if err := h.Auth.Logout(c.Request.Context(), parentID(c), c.GetString(middleware.SessionIDKey)); err != nil {
		failErr(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func truncate(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}
