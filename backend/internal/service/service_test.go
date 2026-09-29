package services

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestAccessTokens(t *testing.T) {
	tok := Tokens{Secret: []byte("0123456789abcdef0123456789abcdef"), AccessTTL: time.Minute}
	s, err := tok.Access("parent-1", "session-1")
	if err != nil {
		t.Fatal(err)
	}
	c, err := tok.ParseAccess(s)
	if err != nil || c.Subject != "parent-1" || c.SessionID != "session-1" {
		t.Fatalf("round trip: %+v %v", c, err)
	}
	other := Tokens{Secret: []byte("another-secret-another-secret-xx"), AccessTTL: time.Minute}
	if _, err := other.ParseAccess(s); !errors.Is(err, ErrBadAccessToken) {
		t.Error("a token signed with another secret must fail")
	}
	expired := Tokens{Secret: tok.Secret, AccessTTL: -time.Minute}
	old, _ := expired.Access("p", "s")
	if _, err := tok.ParseAccess(old); err == nil {
		t.Error("expired token must fail")
	}
	r1, h1, _ := tok.NewRefresh()
	r2, _, _ := tok.NewRefresh()
	if r1 == r2 || len(r1) < 40 || string(HashRefresh(r1)) != string(h1) {
		t.Error("refresh tokens are random and hashed consistently")
	}
}

// fakeGoogle serves a JWKS like https://www.googleapis.com/oauth2/v3/certs.
type fakeGoogle struct {
	key     *rsa.PrivateKey
	kid     string
	fetches atomic.Int32
	srv     *httptest.Server
}

func newFakeGoogle(t *testing.T) *fakeGoogle {
	k, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	f := &fakeGoogle{key: k, kid: "kid-1"}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.fetches.Add(1)
		w.Header().Set("Cache-Control", "public, max-age=3600")
		json.NewEncoder(w).Encode(map[string]any{"keys": []map[string]string{{
			"kid": f.kid, "kty": "RSA", "alg": "RS256",
			"n": base64.RawURLEncoding.EncodeToString(f.key.N.Bytes()),
			"e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(f.key.E)).Bytes()),
		}}})
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeGoogle) token(t *testing.T, edit func(c jwt.MapClaims)) string {
	c := jwt.MapClaims{
		"iss": "https://accounts.google.com", "aud": "android-client", "sub": "google-123",
		"email": "Ammi@Gmail.com", "email_verified": true, "name": "Ammi", "picture": "https://pic",
		"iat": time.Now().Unix(), "exp": time.Now().Add(time.Hour).Unix(),
	}
	if edit != nil {
		edit(c)
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, c)
	tok.Header["kid"] = f.kid
	s, err := tok.SignedString(f.key)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestGoogleIDTokens(t *testing.T) {
	g := newFakeGoogle(t)
	v := NewGoogleIDTokens([]string{"ios-client", "android-client"})
	v.CertsURL = g.srv.URL
	ctx := context.Background()

	u, err := v.Verify(ctx, g.token(t, nil))
	if err != nil {
		t.Fatal(err)
	}
	if u.Sub != "google-123" || u.Email != "ammi@gmail.com" || u.Name != "Ammi" {
		t.Errorf("user: %+v", u)
	}
	for i := 0; i < 5; i++ {
		if _, err := v.Verify(ctx, g.token(t, nil)); err != nil {
			t.Fatal(err)
		}
	}
	if n := g.fetches.Load(); n != 1 {
		t.Errorf("Google's keys are cached: fetched %d times", n)
	}

	bad := map[string]func(c jwt.MapClaims){
		"wrong audience":   func(c jwt.MapClaims) { c["aud"] = "someone-else" },
		"wrong issuer":     func(c jwt.MapClaims) { c["iss"] = "evil.example" },
		"expired":          func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() },
		"email unverified": func(c jwt.MapClaims) { c["email_verified"] = false },
	}
	for name, edit := range bad {
		if _, err := v.Verify(ctx, g.token(t, edit)); !errors.Is(err, ErrBadGoogleToken) {
			t.Errorf("%s: want ErrBadGoogleToken, got %v", name, err)
		}
	}

	// a token signed by someone else's key
	other := newFakeGoogle(t)
	if _, err := v.Verify(ctx, other.token(t, nil)); !errors.Is(err, ErrBadGoogleToken) {
		t.Errorf("foreign signature: %v", err)
	}

	// Google rotates keys: an unknown kid triggers one refetch
	g.key, _ = rsa.GenerateKey(rand.Reader, 2048)
	g.kid = "kid-2"
	time.Sleep(10 * time.Millisecond)
	v.lastFetch = time.Now().Add(-time.Minute)
	if _, err := v.Verify(ctx, g.token(t, nil)); err != nil {
		t.Errorf("rotated key: %v", err)
	}
}

func TestDevGoogle(t *testing.T) {
	d := DevGoogle{}
	u, err := d.Verify(context.Background(), "dev:Abbu@Example.com")
	if err != nil || u.Email != "abbu@example.com" || u.Sub != "dev-abbu@example.com" {
		t.Fatalf("%+v %v", u, err)
	}
	if _, err := d.Verify(context.Background(), "not-a-token"); err == nil {
		t.Error("only dev:<email> is accepted")
	}
}
