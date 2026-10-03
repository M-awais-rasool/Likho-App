package handler

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/domain"
)

// statusOf maps a domain error kind to its HTTP status.
var statusOf = map[domain.Kind]int{
	domain.KindInvalid:         http.StatusBadRequest,
	domain.KindUnauthorized:    http.StatusUnauthorized,
	domain.KindPaymentRequired: http.StatusPaymentRequired,
	domain.KindNotFound:        http.StatusNotFound,
	domain.KindConflict:        http.StatusConflict,
}

// writeError answers {"error": "<code>", "message": "<text>"}. Domain errors
// keep their code; anything else is logged and hidden behind a 500.
func writeError(c *gin.Context, err error) {
	var de *domain.Error
	if errors.As(err, &de) {
		c.AbortWithStatusJSON(statusOf[de.Kind], gin.H{"error": de.Code, "message": de.Message})
		return
	}
	slog.Error("request failed", "path", c.FullPath(), "err", err)
	c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "Something went wrong"})
}
