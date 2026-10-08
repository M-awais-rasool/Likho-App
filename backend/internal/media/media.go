// Package media serves the course's pictures and recordings from a folder
// on the server's disk (MEDIA_DIR): they are not in the app or in git.
//
// At start-up every file is indexed once: its path, size, type and a hash of
// its bytes. The app first reads the manifest (GET /v1/media: path -> hash),
// then asks for each file as /media/<path>?v=<hash>. A URL with the current
// hash never changes, so it is cached for a year (by the phone, a CDN or the
// reverse proxy); the file itself is sent with sendfile, ranges and 304s by
// net/http. Nothing is read from disk per request except the file sent.
package media

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Types are the files the library serves, by extension.
var Types = map[string]string{
	".m4a":  "audio/mp4",
	".mp3":  "audio/mpeg",
	".wav":  "audio/wav",
	".lip":  "application/octet-stream", // mouth movement next to a recording (tools/voice)
	".png":  "image/png",
	".jpg":  "image/jpeg",
	".webp": "image/webp",
}

// File is one indexed file.
type File struct {
	Path string // "voice/line-3f0c….m4a", "pictures/cat.png"
	Hash string // first 16 hex digits of the SHA-256 of its bytes
	Size int64
	Type string
	Mod  time.Time
	abs  string
}

// Library is the indexed folder. It does not change while the API runs:
// after new files are copied in, the API is restarted (see the README).
type Library struct {
	Dir   string
	files map[string]File

	// the manifest as served: JSON, its gzip copy and its ETag
	JSON, Gzip []byte
	ETag       string
	Bytes      int64 // all files together
}

// Open indexes [dir]. A folder that does not exist gives an empty library
// (the app then shows placeholders and uses the device voice).
func Open(dir string) (*Library, error) {
	l := &Library{Dir: dir, files: map[string]File{}}
	if dir == "" {
		return l, l.build()
	}
	if _, err := os.Stat(dir); errors.Is(err, fs.ErrNotExist) {
		slog.Warn("media folder not found: pictures and recordings are not served", "dir", dir)
		return l, l.build()
	}
	err := filepath.WalkDir(dir, func(abs string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		name := d.Name()
		if strings.HasPrefix(name, ".") {
			if d.IsDir() && abs != dir {
				return filepath.SkipDir
			}
			return nil
		}
		if d.IsDir() {
			return nil
		}
		typ, ok := Types[strings.ToLower(filepath.Ext(name))]
		if !ok {
			return nil
		}
		rel, err := filepath.Rel(dir, abs)
		if err != nil {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		hash, err := hashFile(abs)
		if err != nil {
			return err
		}
		p := filepath.ToSlash(rel)
		l.files[p] = File{Path: p, Hash: hash, Size: info.Size(), Type: typ, Mod: info.ModTime(), abs: abs}
		l.Bytes += info.Size()
		return nil
	})
	if err != nil {
		return nil, err
	}
	return l, l.build()
}

func hashFile(name string) (string, error) {
	f, err := os.Open(name)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil))[:16], nil
}

// build makes the manifest: {"version": "…", "files": {"path": "hash"}}.
func (l *Library) build() error {
	files := make(map[string]string, len(l.files))
	for p, f := range l.files {
		files[p] = f.Hash
	}
	body, err := json.Marshal(struct {
		Files map[string]string `json:"files"`
	}{files}) // map keys are sorted: the same files give the same bytes
	if err != nil {
		return err
	}
	sum := sha256.Sum256(body)
	version := hex.EncodeToString(sum[:])[:16]
	var gz bytes.Buffer
	w, _ := gzip.NewWriterLevel(&gz, gzip.BestCompression)
	_, _ = w.Write(body)
	_ = w.Close()
	l.JSON, l.Gzip, l.ETag = body, gz.Bytes(), `"`+version+`"`
	return nil
}

// Lookup finds a file by its path in the library ("pictures/cat.png").
// Paths that leave the folder ("../x") or were not indexed are not found.
func (l *Library) Lookup(p string) (File, bool) {
	clean := path.Clean("/" + p)[1:]
	f, ok := l.files[clean]
	return f, ok && clean == p
}

// Len is the number of files.
func (l *Library) Len() int { return len(l.files) }

// Missing returns the paths of [want] that the library does not have, sorted.
func (l *Library) Missing(want []string) []string {
	var out []string
	for _, p := range want {
		if _, ok := l.files[p]; !ok {
			out = append(out, p)
		}
	}
	sort.Strings(out)
	return out
}

// Open opens an indexed file for sending.
func (f File) Open() (*os.File, error) { return os.Open(f.abs) }
