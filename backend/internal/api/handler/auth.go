package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/middleware"
	"likho/backend/internal/domain"
	"likho/backend/internal/service"
)

type AuthHandler struct {
	auth *service.AuthService
}

// GoogleSignIn: POST /v1/auth/google {"idToken", "device"}
// The only way in. A new Google account gets a new Likho account (201); an
// existing one continues (200). Answers tokens + the whole account.
func (h *AuthHandler) GoogleSignIn(c *gin.Context) {
	var in struct {
		IDToken string `json:"idToken"`
		Device  string `json:"device"`
	}
	if !bind(c, &in) {
		return
	}
	if strings.TrimSpace(in.IDToken) == "" {
		writeError(c, domain.Invalid("idToken is required"))
		return
	}
	device := in.Device
	if device == "" {
		device = c.GetHeader("User-Agent")
	}
	out, err := h.auth.SignInWithGoogle(c.Request.Context(), in.IDToken, truncate(device, 120), middleware.Client(c))
	if err != nil {
		writeError(c, err)
		return
	}
	status := http.StatusOK
	if out.IsNewAccount {
		status = http.StatusCreated
	}
	writeJSON(c, status, out)
}

// Refresh: POST /v1/auth/refresh {"refreshToken"} -> a new token pair.
func (h *AuthHandler) Refresh(c *gin.Context) {
	var in struct {
		RefreshToken string `json:"refreshToken"`
	}
	if !bind(c, &in) {
		return
	}
	if in.RefreshToken == "" {
		writeError(c, domain.Invalid("refreshToken is required"))
		return
	}
	out, err := h.auth.Refresh(c.Request.Context(), in.RefreshToken)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// Logout: POST /v1/auth/logout -> this device is signed out.
func (h *AuthHandler) Logout(c *gin.Context) {
	if err := h.auth.Logout(c.Request.Context(), parentID(c), middleware.SessionID(c)); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

func truncate(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}
