// Package geo works out which country a family uses Likho from, for the
// admin panel. In order of trust:
//
//  1. a country header set by the CDN or load balancer in front of the API
//     (e.g. Cloudflare's CF-IPCountry), when COUNTRY_HEADER names one
//  2. the client IP looked up in a GeoIP country database (MaxMind or
//     DB-IP .mmdb, GEOIP_DB), when there is one
//  3. the region of the phone's language setting (en_PK -> PK), which the
//     app sends; good enough when nothing better is known
//
// Only the 2-letter country code is kept, never the IP address.
package geo

import (
	"log/slog"
	"net/netip"
	"strings"

	"github.com/oschwald/maxminddb-golang/v2"
)

// Where a country came from.
const (
	SourceCDN    = "cdn"
	SourceIP     = "ip"
	SourceDevice = "device"
)

// Resolver finds countries. The zero value uses only the phone's region.
type Resolver struct {
	db *maxminddb.Reader
}

// Open loads the GeoIP database at [path] ("" = none). A database that
// cannot be read is logged and skipped: countries then come from the other
// sources.
func Open(path string) *Resolver {
	r := &Resolver{}
	if path == "" {
		return r
	}
	db, err := maxminddb.Open(path)
	if err != nil {
		slog.Warn("geoip database not loaded", "path", path, "err", err)
		return r
	}
	slog.Info("geoip database loaded", "path", path, "type", db.Metadata.DatabaseType)
	r.db = db
	return r
}

// Enabled reports whether IP lookups are possible.
func (r *Resolver) Enabled() bool { return r != nil && r.db != nil }

// Close releases the database.
func (r *Resolver) Close() {
	if r.Enabled() {
		_ = r.db.Close()
	}
}

// Country returns the country code and its source ("", "" when unknown).
// [cdn] is the trusted header's value, [ip] the client address, [region]
// what the phone says.
func (r *Resolver) Country(cdn, ip, region string) (code, source string) {
	if c, ok := Code(cdn); ok {
		return c, SourceCDN
	}
	if r.Enabled() {
		if addr, err := netip.ParseAddr(ip); err == nil && addr.IsGlobalUnicast() && !addr.IsPrivate() {
			var rec struct {
				Country struct {
					ISOCode string `maxminddb:"iso_code"`
				} `maxminddb:"country"`
			}
			if err := r.db.Lookup(addr).Decode(&rec); err == nil {
				if c, ok := Code(rec.Country.ISOCode); ok {
					return c, SourceIP
				}
			}
		}
	}
	if c, ok := Code(region); ok {
		return c, SourceDevice
	}
	return "", ""
}

// Code cleans a 2-letter country code ("pk" -> "PK"). Placeholders that
// CDNs send for unknown or anonymous visitors (XX, T1) are not countries.
func Code(s string) (string, bool) {
	s = strings.ToUpper(strings.TrimSpace(s))
	if len(s) != 2 || s[0] < 'A' || s[0] > 'Z' || s[1] < 'A' || s[1] > 'Z' {
		return "", false
	}
	switch s {
	case "XX", "ZZ", "T1", "EU", "AP":
		return "", false
	}
	return s, true
}
