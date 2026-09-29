// Package service is the business layer between the HTTP handlers and the
// repositories: it checks input, applies Likho's rules (with the course
// content), keeps the cache in step and returns model types or domain
// errors. It knows nothing about HTTP.
package service

import (
	"context"
	"time"

	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// AuthService: "Continue with Google" is the only way in. There is no
// sign-up: a Google account seen for the first time gets a new Likho
// account, a returning one continues where it left off.
type AuthService struct {
	accounts *repository.AccountRepository
	sessions *repository.SessionRepository
	google   GoogleVerifier
	tokens   Tokens
	me       *AccountService
}

func NewAuthService(accounts *repository.AccountRepository, sessions *repository.SessionRepository, google GoogleVerifier, tokens Tokens, me *AccountService) *AuthService {
	return &AuthService{accounts: accounts, sessions: sessions, google: google, tokens: tokens, me: me}
}

// SignInWithGoogle verifies the Google ID token, finds or creates the
// account, opens a session for this device and returns tokens plus the
// whole account (so the app needs no second request).
func (s *AuthService) SignInWithGoogle(ctx context.Context, idToken, device string) (model.SignIn, error) {
	user, err := s.google.Verify(ctx, idToken)
	if err != nil {
		return model.SignIn{}, err
	}
	parent, created, err := s.accounts.SignInWithGoogle(ctx, user)
	if err != nil {
		return model.SignIn{}, err
	}
	tokens, err := s.newSession(ctx, parent.ID, device)
	if err != nil {
		return model.SignIn{}, err
	}
	me, err := s.me.Me(ctx, parent.ID)
	if err != nil {
		return model.SignIn{}, err
	}
	return model.SignIn{Tokens: tokens, IsNewAccount: created, Me: me}, nil
}

func (s *AuthService) newSession(ctx context.Context, parentID, device string) (model.Tokens, error) {
	refresh, hash, err := s.tokens.NewRefresh()
	if err != nil {
		return model.Tokens{}, err
	}
	sid, err := s.sessions.Create(ctx, parentID, hash, device, time.Now().Add(s.tokens.RefreshTTL))
	if err != nil {
		return model.Tokens{}, err
	}
	return s.pair(parentID, sid, refresh)
}

func (s *AuthService) pair(parentID, sessionID, refresh string) (model.Tokens, error) {
	access, err := s.tokens.Access(parentID, sessionID)
	if err != nil {
		return model.Tokens{}, err
	}
	return model.Tokens{AccessToken: access, ExpiresIn: int(s.tokens.AccessTTL.Seconds()), RefreshToken: refresh}, nil
}

// Refresh swaps a refresh token for a new pair (the old one stops working).
func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (model.Tokens, error) {
	next, hash, err := s.tokens.NewRefresh()
	if err != nil {
		return model.Tokens{}, err
	}
	parentID, sid, err := s.sessions.Rotate(ctx, HashRefresh(refreshToken), hash, time.Now().Add(s.tokens.RefreshTTL))
	if err != nil {
		return model.Tokens{}, err
	}
	return s.pair(parentID, sid, next)
}

// Logout ends this device's session.
func (s *AuthService) Logout(ctx context.Context, parentID, sessionID string) error {
	return s.sessions.Revoke(ctx, parentID, sessionID)
}
