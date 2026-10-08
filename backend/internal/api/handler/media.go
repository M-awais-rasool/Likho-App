package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/media"
)

// MediaHandler serves the course's pictures and recordings (see package media).
type MediaHandler struct {
	Library *media.Library
}

// Manifest: GET /v1/media -> {"files": {"voice/line-….m4a": "<hash>", ...}}.
// From memory, gzipped, 304 when the app has this version.
func (h *MediaHandler) Manifest(c *gin.Context) {
	l := h.Library
	c.Header("ETag", l.ETag)
	c.Header("Cache-Control", "public, max-age=300")
	c.Header("Vary", "Accept-Encoding")
	if match := c.GetHeader("If-None-Match"); match != "" && strings.Contains(match, l.ETag) {
		c.Status(http.StatusNotModified)
		return
	}
	if strings.Contains(c.GetHeader("Accept-Encoding"), "gzip") {
		c.Header("Content-Encoding", "gzip")
		c.Data(http.StatusOK, "application/json; charset=utf-8", l.Gzip)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", l.JSON)
}

// File: GET /media/<path>[?v=<hash>] -> the file. With the file's current
// hash in v the answer is cached for a year (the URL never changes);
// without it, for an hour. Ranges, HEAD and If-None-Match / If-Modified-Since
// are answered by net/http, which sends the file with sendfile.
func (h *MediaHandler) File(c *gin.Context) {
	f, ok := h.Library.Lookup(strings.TrimPrefix(c.Param("path"), "/"))
	if !ok {
		writeJSON(c, http.StatusNotFound, gin.H{"error": "not_found", "message": "No such file"})
		return
	}
	etag := `"` + f.Hash + `"`
	if c.Query("v") == f.Hash {
		c.Header("Cache-Control", "public, max-age=31536000, immutable")
	} else {
		c.Header("Cache-Control", "public, max-age=3600")
	}
	c.Header("ETag", etag)
	if match := c.GetHeader("If-None-Match"); match != "" && strings.Contains(match, etag) {
		c.Status(http.StatusNotModified)
		return
	}
	file, err := f.Open()
	if err != nil {
		writeJSON(c, http.StatusNotFound, gin.H{"error": "not_found", "message": "No such file"})
		return
	}
	defer file.Close()
	c.Header("Content-Type", f.Type)
	http.ServeContent(c.Writer, c.Request, f.Path, f.Mod, file)
}
