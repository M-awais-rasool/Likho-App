package services

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"sync/atomic"
	"time"

	"likho/backend/repository"
)

// Course serves the course content (the same JSON the app bundles as
// assets/data/course.json). It lives in Postgres; the newest version is
// kept in memory, already gzipped, with an ETag, so GET /v1/course costs no
// database work and phones only download it when it changed.
type Course struct {
	store   *repository.Store
	current atomic.Pointer[CourseContent]
}

type CourseContent struct {
	ETag   string
	JSON   []byte
	Gzip   []byte
	levels map[int]LevelInfo
}

// LevelInfo is what the API needs to know about a level.
type LevelInfo struct {
	RequiresSubscription bool
	IsBoss               bool
}

func NewCourse(store *repository.Store) *Course { return &Course{store: store} }

func (c *Course) Current() *CourseContent { return c.current.Load() }

// Level looks up a map level (1..36).
func (c *Course) Level(n int) (LevelInfo, bool) {
	cur := c.current.Load()
	if cur == nil {
		return LevelInfo{}, false
	}
	l, ok := cur.levels[n]
	return l, ok
}

// Import stores [path] as the newest course when it differs from what is
// served (so deploying a new course.json is enough to publish it).
func (c *Course) Import(ctx context.Context, path string) error {
	if path == "" {
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			slog.Warn("course file not found, serving the stored course", "path", path)
			return nil
		}
		return err
	}
	if !json.Valid(raw) {
		return fmt.Errorf("course file %s is not valid JSON", path)
	}
	sum := sha256.Sum256(raw)
	sha := hex.EncodeToString(sum[:])
	if latest, err := c.store.LatestCourse(ctx); err == nil && latest.Sha256 == sha {
		return nil
	}
	if err := c.store.SaveCourse(ctx, sha, string(raw)); err != nil {
		return err
	}
	slog.Info("course imported", "path", path, "sha256", sha[:12])
	return nil
}

// Reload loads the newest stored course into memory if it changed.
func (c *Course) Reload(ctx context.Context) error {
	cv, err := c.store.LatestCourse(ctx)
	if err != nil {
		return err
	}
	etag := `"` + cv.Sha256[:16] + `"`
	if cur := c.current.Load(); cur != nil && cur.ETag == etag {
		return nil
	}
	content, err := buildCourse(etag, []byte(cv.Body))
	if err != nil {
		return err
	}
	c.current.Store(content)
	slog.Info("course loaded", "etag", etag, "levels", len(content.levels))
	return nil
}

// Watch reloads every [every] so a course imported by another server shows
// up without a restart.
func (c *Course) Watch(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := c.Reload(ctx); err != nil && !errors.Is(err, context.Canceled) {
				slog.Warn("course reload", "err", err)
			}
		}
	}
}

func buildCourse(etag string, body []byte) (*CourseContent, error) {
	var parsed struct {
		Levels []struct {
			Number               int  `json:"number"`
			Placement            bool `json:"placement"`
			IsBoss               bool `json:"isBoss"`
			RequiresSubscription bool `json:"requiresSubscription"`
		} `json:"levels"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, fmt.Errorf("course: %w", err)
	}
	levels := make(map[int]LevelInfo, len(parsed.Levels))
	for _, l := range parsed.Levels {
		if !l.Placement {
			levels[l.Number] = LevelInfo{RequiresSubscription: l.RequiresSubscription, IsBoss: l.IsBoss}
		}
	}
	var gz bytes.Buffer
	w, _ := gzip.NewWriterLevel(&gz, gzip.BestCompression)
	if _, err := w.Write(body); err != nil {
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return &CourseContent{ETag: etag, JSON: body, Gzip: gz.Bytes(), levels: levels}, nil
}
