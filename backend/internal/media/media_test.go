package media_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/handler"
	"likho/backend/internal/media"
)

func folder(t *testing.T) string {
	dir := t.TempDir()
	write := func(p, body string) {
		full := filepath.Join(dir, p)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("voice/line-1.m4a", "0123456789")
	write("voice/line-1.lip", "lip")
	write("pictures/cat.png", "png")
	write("notes.txt", "not served")       // unknown type
	write(".cache/x.png", "hidden folder") // hidden
	return dir
}

func TestLibraryIndexesItsFiles(t *testing.T) {
	lib, err := media.Open(folder(t))
	if err != nil {
		t.Fatal(err)
	}
	if lib.Len() != 3 {
		t.Fatalf("files: %d", lib.Len())
	}
	var m struct{ Files map[string]string }
	if err := json.Unmarshal(lib.JSON, &m); err != nil || len(m.Files) != 3 || len(m.Files["pictures/cat.png"]) != 16 {
		t.Fatalf("manifest: %s", lib.JSON)
	}
	for _, p := range []string{"../voice/line-1.m4a", "voice/../pictures/cat.png", "/pictures/cat.png", "notes.txt", ".cache/x.png"} {
		if _, ok := lib.Lookup(p); ok {
			t.Errorf("%q must not be served", p)
		}
	}
	if got := lib.Missing([]string{"pictures/cat.png", "pictures/dog.png"}); len(got) != 1 || got[0] != "pictures/dog.png" {
		t.Errorf("missing: %v", got)
	}
	again, _ := media.Open(lib.Dir)
	if again.ETag != lib.ETag {
		t.Error("the same files give the same manifest version")
	}
	empty, err := media.Open(filepath.Join(t.TempDir(), "none"))
	if err != nil || empty.Len() != 0 {
		t.Errorf("a missing folder is an empty library: %v", err)
	}
}

func TestFilesAreServedWithLongCachingAndRanges(t *testing.T) {
	gin.SetMode(gin.TestMode)
	lib, _ := media.Open(folder(t))
	h := &handler.MediaHandler{Library: lib}
	r := gin.New()
	r.GET("/v1/media", h.Manifest)
	r.GET("/media/*path", h.File)
	r.HEAD("/media/*path", h.File)
	f, _ := lib.Lookup("voice/line-1.m4a")
	do := func(method, url string, hdr ...string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, url, nil)
		for i := 0; i+1 < len(hdr); i += 2 {
			req.Header.Set(hdr[i], hdr[i+1])
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}

	w := do("GET", "/media/voice/line-1.m4a?v="+f.Hash)
	if w.Code != 200 || w.Body.String() != "0123456789" || w.Header().Get("Content-Type") != "audio/mp4" ||
		!strings.Contains(w.Header().Get("Cache-Control"), "immutable") {
		t.Fatalf("file: %d %q %v", w.Code, w.Body.String(), w.Header())
	}
	if w := do("GET", "/media/voice/line-1.m4a?v=old"); strings.Contains(w.Header().Get("Cache-Control"), "immutable") {
		t.Error("an old version is not cached for a year")
	}
	if w := do("GET", "/media/voice/line-1.m4a", "Range", "bytes=2-4"); w.Code != http.StatusPartialContent || w.Body.String() != "234" {
		t.Errorf("range: %d %q", w.Code, w.Body.String())
	}
	if w := do("GET", "/media/voice/line-1.m4a", "If-None-Match", `"`+f.Hash+`"`); w.Code != http.StatusNotModified {
		t.Errorf("etag: %d", w.Code)
	}
	if w := do("HEAD", "/media/pictures/cat.png"); w.Code != 200 || w.Header().Get("Content-Length") != "3" {
		t.Errorf("head: %d %v", w.Code, w.Header())
	}
	for _, bad := range []string{"/media/../../etc/passwd", "/media/notes.txt", "/media/pictures/dog.png"} {
		if w := do("GET", bad); w.Code != http.StatusNotFound {
			t.Errorf("%s: %d", bad, w.Code)
		}
	}

	w = do("GET", "/v1/media", "Accept-Encoding", "gzip")
	if w.Code != 200 || w.Header().Get("Content-Encoding") != "gzip" || w.Header().Get("ETag") != lib.ETag {
		t.Fatalf("manifest: %d %v", w.Code, w.Header())
	}
	if w := do("GET", "/v1/media", "If-None-Match", lib.ETag); w.Code != http.StatusNotModified {
		t.Errorf("manifest etag: %d", w.Code)
	}
}
