package service

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// GoogleVerifier checks a Google ID token (from Google Sign-In on the phone)
// and tells who signed in.
type GoogleVerifier interface {
	Verify(ctx context.Context, idToken string) (model.GoogleUser, error)
}

const googleCertsURL = "https://www.googleapis.com/oauth2/v3/certs"

// GoogleIDTokens verifies ID tokens locally: signature (Google's public
// keys, cached for as long as Google says), issuer, audience (our OAuth
// client IDs), expiry and a verified email. No call to Google per sign-in.
type GoogleIDTokens struct {
	ClientIDs []string
	CertsURL  string
	HTTP      *http.Client

	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	expires   time.Time
	lastFetch time.Time
}

func NewGoogleIDTokens(clientIDs []string) *GoogleIDTokens {
	return &GoogleIDTokens{ClientIDs: clientIDs, CertsURL: googleCertsURL, HTTP: &http.Client{Timeout: 5 * time.Second}}
}

type googleClaims struct {
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	jwt.RegisteredClaims
}

func (g *GoogleIDTokens) Verify(ctx context.Context, idToken string) (model.GoogleUser, error) {
	var claims googleClaims
	_, err := jwt.ParseWithClaims(idToken, &claims, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string)
		return g.key(ctx, kid)
	},
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithIssuedAt(),
		jwt.WithExpirationRequired(),
		jwt.WithLeeway(30*time.Second),
	)
	if err != nil {
		return model.GoogleUser{}, fmt.Errorf("%w: %v", domain.ErrBadGoogleToken, err)
	}
	if claims.Issuer != "accounts.google.com" && claims.Issuer != "https://accounts.google.com" {
		return model.GoogleUser{}, fmt.Errorf("%w: issuer %q", domain.ErrBadGoogleToken, claims.Issuer)
	}
	if !slices.ContainsFunc(claims.Audience, func(a string) bool { return slices.Contains(g.ClientIDs, a) }) {
		return model.GoogleUser{}, fmt.Errorf("%w: audience %v", domain.ErrBadGoogleToken, claims.Audience)
	}
	if claims.Subject == "" || claims.Email == "" || !claims.EmailVerified {
		return model.GoogleUser{}, fmt.Errorf("%w: no verified email", domain.ErrBadGoogleToken)
	}
	return model.GoogleUser{Sub: claims.Subject, Email: strings.ToLower(claims.Email), Name: claims.Name, Picture: claims.Picture}, nil
}

// key returns Google's public key [kid], fetching the key set when the
// cache is empty, expired, or does not know the key (Google rotated keys).
func (g *GoogleIDTokens) key(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	g.mu.RLock()
	k, ok := g.keys[kid]
	fresh := time.Now().Before(g.expires)
	g.mu.RUnlock()
	if ok && fresh {
		return k, nil
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	if k, ok := g.keys[kid]; ok && time.Now().Before(g.expires) {
		return k, nil // another request refreshed meanwhile
	}
	if !ok && time.Since(g.lastFetch) < 10*time.Second && time.Now().Before(g.expires) {
		return nil, fmt.Errorf("unknown key id %q", kid) // do not hammer Google with bad tokens
	}
	if err := g.fetch(ctx); err != nil {
		if k, ok := g.keys[kid]; ok {
			return k, nil // keep working on the old keys if Google is unreachable
		}
		return nil, err
	}
	if k, ok := g.keys[kid]; ok {
		return k, nil
	}
	return nil, fmt.Errorf("unknown key id %q", kid)
}

func (g *GoogleIDTokens) fetch(ctx context.Context) error {
	g.lastFetch = time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.CertsURL, nil)
	if err != nil {
		return err
	}
	res, err := g.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("google certs: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("google certs: status %d", res.StatusCode)
	}
	var set struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(res.Body).Decode(&set); err != nil {
		return fmt.Errorf("google certs: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "RSA" {
			continue
		}
		n, err1 := base64.RawURLEncoding.DecodeString(k.N)
		e, err2 := base64.RawURLEncoding.DecodeString(k.E)
		if err1 != nil || err2 != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(n), E: int(new(big.Int).SetBytes(e).Int64())}
	}
	if len(keys) == 0 {
		return errors.New("google certs: no keys")
	}
	g.keys = keys
	g.expires = time.Now().Add(maxAge(res.Header.Get("Cache-Control"), time.Hour))
	return nil
}

// maxAge reads "max-age=N" from a Cache-Control header.
func maxAge(cc string, def time.Duration) time.Duration {
	for _, part := range strings.Split(cc, ",") {
		part = strings.TrimSpace(part)
		if v, ok := strings.CutPrefix(part, "max-age="); ok {
			var secs int
			if _, err := fmt.Sscan(v, &secs); err == nil && secs > 0 {
				return time.Duration(secs) * time.Second
			}
		}
	}
	return def
}

// DevGoogle accepts "dev:<email>" as an ID token so the app can be tried
// before Google Sign-In is set up. Development only (config refuses it in
// production).
type DevGoogle struct{ Next GoogleVerifier }

func (d DevGoogle) Verify(ctx context.Context, idToken string) (model.GoogleUser, error) {
	if email, ok := strings.CutPrefix(idToken, "dev:"); ok && strings.Contains(email, "@") {
		email = strings.ToLower(strings.TrimSpace(email))
		name, _, _ := strings.Cut(email, "@")
		return model.GoogleUser{Sub: "dev-" + email, Email: email, Name: name}, nil
	}
	if d.Next == nil {
		return model.GoogleUser{}, domain.ErrBadGoogleToken
	}
	return d.Next.Verify(ctx, idToken)
}
