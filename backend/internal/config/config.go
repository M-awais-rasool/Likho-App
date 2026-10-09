// Package config reads every setting from environment variables (see
// .env.example). Nothing else in the app reads the environment.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Env  string // "development" or "production"
	Port string

	DatabaseURL string
	DBMaxConns  int // connections to Postgres (0 = by CPUs, 8 to 20)
	RedisURL    string

	// Google OAuth client IDs whose ID tokens we accept (iOS, Android, web).
	GoogleClientIDs []string

	JWTSecret  []byte
	AccessTTL  time.Duration // short-lived JWT
	RefreshTTL time.Duration // long-lived, rotated on every use

	// Learning content: built into the binary (backend/content). ContentDir
	// loads it from a folder instead (to try new content without a
	// rebuild). ContentDrafts also serves courses marked "draft"; it is on
	// by default in development and off in production.
	ContentDir    string
	ContentDrafts bool

	// Development only: accept "dev:<email>" instead of a Google ID token.
	DevLogin bool

	// Admin panel. AdminDir serves its build (admin/dist) at /admin/; the
	// bootstrap owner is created at start-up when there are no admins yet.
	AdminDir               string
	AdminBootstrapEmail    string
	AdminBootstrapPassword string

	// Pictures and recordings of the courses: a folder on the server's
	// disk (not in the binary, not in git), served at /media/.
	MediaDir string

	// Countries of families: a header set by the CDN in front of the API
	// (e.g. CF-IPCountry) and/or a GeoIP country database (.mmdb).
	CountryHeader string
	GeoIPDB       string

	// Proxies whose X-Forwarded-For is believed (IPs or CIDRs, e.g. the
	// Docker network nginx comes in from). Empty = none: the client's IP
	// is the connection's, so nobody can fake it to dodge the rate limits.
	TrustedProxies []string
}

func (c Config) Production() bool { return c.Env == "production" }

func Load() (Config, error) {
	c := Config{
		Env:             get("APP_ENV", "development"),
		Port:            get("PORT", "8080"),
		DatabaseURL:     get("DATABASE_URL", "postgres://likho:likho@localhost:5432/likho?sslmode=disable"),
		RedisURL:        get("REDIS_URL", "redis://localhost:6379/0"),
		DBMaxConns:      number("DB_MAX_CONNS", 0),
		GoogleClientIDs: list(os.Getenv("GOOGLE_CLIENT_IDS")),
		JWTSecret:       []byte(os.Getenv("JWT_SECRET")),
		AccessTTL:       duration("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTTL:      duration("REFRESH_TOKEN_TTL", 60*24*time.Hour),
		ContentDir:      os.Getenv("CONTENT_DIR"),
		MediaDir:        get("MEDIA_DIR", "../media"),
		DevLogin:        boolean("DEV_LOGIN", false),

		AdminDir:               os.Getenv("ADMIN_DIR"),
		AdminBootstrapEmail:    strings.ToLower(strings.TrimSpace(os.Getenv("ADMIN_BOOTSTRAP_EMAIL"))),
		AdminBootstrapPassword: os.Getenv("ADMIN_BOOTSTRAP_PASSWORD"),
		CountryHeader:          strings.TrimSpace(os.Getenv("COUNTRY_HEADER")),
		GeoIPDB:                os.Getenv("GEOIP_DB"),
		TrustedProxies:         list(os.Getenv("TRUSTED_PROXIES")),
	}
	c.ContentDrafts = boolean("CONTENT_DRAFTS", !c.Production())

	var errs []error
	if len(c.JWTSecret) < 32 {
		errs = append(errs, errors.New("JWT_SECRET must be at least 32 characters"))
	}
	if len(c.GoogleClientIDs) == 0 && !c.DevLogin {
		errs = append(errs, errors.New("GOOGLE_CLIENT_IDS is required (comma separated OAuth client IDs)"))
	}
	if c.AdminBootstrapEmail != "" && len(c.AdminBootstrapPassword) < 10 {
		errs = append(errs, errors.New("ADMIN_BOOTSTRAP_PASSWORD must be at least 10 characters"))
	}
	if c.Production() && c.DevLogin {
		errs = append(errs, errors.New("DEV_LOGIN cannot be on in production"))
	}
	return c, errors.Join(errs...)
}

func get(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func list(v string) []string {
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func duration(key string, def time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		panic(fmt.Sprintf("%s: %v", key, err))
	}
	return d
}

func boolean(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		panic(fmt.Sprintf("%s: %v", key, err))
	}
	return b
}

func number(key string, def int) int {
	if n, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key))); err == nil {
		return n
	}
	return def
}
