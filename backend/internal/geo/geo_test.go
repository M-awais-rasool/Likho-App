package geo

import "testing"

func TestCountryOrderOfTrust(t *testing.T) {
	r := Open("")
	cases := []struct{ cdn, ip, region, code, source string }{
		{"pk", "8.8.8.8", "GB", "PK", SourceCDN},
		{"XX", "8.8.8.8", "gb", "GB", SourceDevice}, // CDN does not know, no GeoIP database
		{"", "192.168.1.20", "", "", ""},
		{"T1", "", "1x", "", ""},
	}
	for _, c := range cases {
		code, source := r.Country(c.cdn, c.ip, c.region)
		if code != c.code || source != c.source {
			t.Errorf("Country(%q, %q, %q) = %q %q, want %q %q", c.cdn, c.ip, c.region, code, source, c.code, c.source)
		}
	}
}

func TestMissingDatabaseIsSkipped(t *testing.T) {
	if r := Open("/no/such/file.mmdb"); r.Enabled() {
		t.Error("a missing database must not be enabled")
	}
}

// With the database from `make geoip`, public IPs get their country.
func TestRealDatabaseWhenPresent(t *testing.T) {
	r := Open("../../geoip/country.mmdb")
	if !r.Enabled() {
		t.Skip("no geoip/country.mmdb (make geoip)")
	}
	defer r.Close()
	if code, source := r.Country("", "8.8.8.8", "PK"); code != "US" || source != SourceIP {
		t.Errorf("8.8.8.8 = %q %q, want US from the IP", code, source)
	}
	if code, source := r.Country("", "192.168.1.5", "PK"); code != "PK" || source != SourceDevice {
		t.Errorf("a LAN address falls back to the phone's region: %q %q", code, source)
	}
}
