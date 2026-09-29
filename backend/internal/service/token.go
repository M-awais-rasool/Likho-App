package service

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Tokens issues the app's own tokens after Google sign-in:
//   - access token: a short-lived signed JWT, checked on every request
//     without touching the database (fast)
//   - refresh token: a long random string, stored hashed, used once to get
//     a new pair (rotation)
type Tokens struct {
	Secret     []byte
	AccessTTL  time.Duration
	RefreshTTL time.Duration
}

var ErrBadAccessToken = errors.New("invalid access token")

// AccessClaims: sub = parent id, sid = session (device) id.
type AccessClaims struct {
	SessionID string `json:"sid"`
	jwt.RegisteredClaims
}

func (t Tokens) Access(parentID, sessionID string) (string, error) {
	now := time.Now()
	claims := AccessClaims{
		SessionID: sessionID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   parentID,
			Issuer:    "likho",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(t.AccessTTL)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.Secret)
}

func (t Tokens) ParseAccess(token string) (AccessClaims, error) {
	var c AccessClaims
	_, err := jwt.ParseWithClaims(token, &c, func(*jwt.Token) (any, error) { return t.Secret, nil },
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithIssuer("likho"),
		jwt.WithExpirationRequired(),
	)
	if err != nil || c.Subject == "" || c.SessionID == "" {
		return AccessClaims{}, ErrBadAccessToken
	}
	return c, nil
}

// NewRefresh returns a random refresh token and the hash to store.
func (t Tokens) NewRefresh() (token string, hash []byte, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", nil, err
	}
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, HashRefresh(token), nil
}

func HashRefresh(token string) []byte {
	h := sha256.Sum256([]byte(token))
	return h[:]
}
