package services

import (
	"context"
	"time"

	"likho/backend/models"
	"likho/backend/repository"
)

// Auth: "Continue with Google" is the only way in. There is no sign-up:
// a Google account seen for the first time gets a new Likho account, a
// returning one continues where it left off.
type Auth struct {
	Store  *repository.Store
	Google GoogleVerifier
	Tokens Tokens
}

// SignInWithGoogle verifies the Google ID token, finds or creates the
// account, opens a session for this device and returns tokens plus the
// whole account (so the app needs no second request).
func (a Auth) SignInWithGoogle(ctx context.Context, idToken, device string) (models.SignIn, error) {
	user, err := a.Google.Verify(ctx, idToken)
	if err != nil {
		return models.SignIn{}, err
	}
	parent, created, err := a.Store.SignInWithGoogle(ctx, user)
	if err != nil {
		return models.SignIn{}, err
	}
	tokens, err := a.newSession(ctx, parent.ID, device)
	if err != nil {
		return models.SignIn{}, err
	}
	me, err := a.Store.Me(ctx, parent.ID)
	if err != nil {
		return models.SignIn{}, err
	}
	return models.SignIn{Tokens: tokens, IsNewAccount: created, Me: me}, nil
}

func (a Auth) newSession(ctx context.Context, parentID, device string) (models.Tokens, error) {
	refresh, hash, err := a.Tokens.NewRefresh()
	if err != nil {
		return models.Tokens{}, err
	}
	sid, err := a.Store.CreateSession(ctx, parentID, hash, device, time.Now().Add(a.Tokens.RefreshTTL))
	if err != nil {
		return models.Tokens{}, err
	}
	return a.pair(parentID, sid, refresh)
}

func (a Auth) pair(parentID, sessionID, refresh string) (models.Tokens, error) {
	access, err := a.Tokens.Access(parentID, sessionID)
	if err != nil {
		return models.Tokens{}, err
	}
	return models.Tokens{AccessToken: access, ExpiresIn: int(a.Tokens.AccessTTL.Seconds()), RefreshToken: refresh}, nil
}

// Refresh swaps a refresh token for a new pair (the old one stops working).
func (a Auth) Refresh(ctx context.Context, refreshToken string) (models.Tokens, error) {
	next, hash, err := a.Tokens.NewRefresh()
	if err != nil {
		return models.Tokens{}, err
	}
	parentID, sid, err := a.Store.RotateSession(ctx, HashRefresh(refreshToken), hash, time.Now().Add(a.Tokens.RefreshTTL))
	if err != nil {
		return models.Tokens{}, err
	}
	return a.pair(parentID, sid, next)
}

// Logout ends this device's session.
func (a Auth) Logout(ctx context.Context, parentID, sessionID string) error {
	return a.Store.RevokeSession(ctx, parentID, sessionID)
}
