package middleware

import (
	"context"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/model"
)

const clientKey = "client"

// ClientInfo reads what the request says about the device: the app's
// X-Likho-Platform, X-Likho-App-Version and X-Likho-Region headers, the
// client IP and, when [countryHeader] is set, the country the CDN in front
// of the API added (e.g. CF-IPCountry).
func ClientInfo(countryHeader string) gin.HandlerFunc {
	return func(c *gin.Context) {
		info := model.ClientInfo{
			IP:         c.ClientIP(),
			Region:     c.GetHeader("X-Likho-Region"),
			Platform:   c.GetHeader("X-Likho-Platform"),
			AppVersion: c.GetHeader("X-Likho-App-Version"),
		}
		if countryHeader != "" {
			info.CountryHeader = c.GetHeader(countryHeader)
		}
		c.Set(clientKey, info)
		c.Next()
	}
}

// Client is the request's device info (see ClientInfo).
func Client(c *gin.Context) model.ClientInfo {
	info, _ := c.Get(clientKey)
	out, _ := info.(model.ClientInfo)
	return out
}

// Track tells [seen] about every signed-in request (it decides how often
// to record it). Runs after Auth.
func Track(seen func(ctx context.Context, parentID string, info model.ClientInfo, force bool)) gin.HandlerFunc {
	return func(c *gin.Context) {
		if id := ParentID(c); id != "" {
			seen(c.Request.Context(), id, Client(c), false)
		}
		c.Next()
	}
}
