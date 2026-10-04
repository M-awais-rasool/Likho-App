package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"log/slog"
	"net/mail"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
	"likho/backend/internal/repository"
)

// AdminAuthService: signing in to the admin panel (email + password,
// a random session token in an HttpOnly cookie) and the team of admins.
type AdminAuthService struct {
	repo       *repository.AdminRepository
	sessionTTL time.Duration
}

func NewAdminAuthService(repo *repository.AdminRepository) *AdminAuthService {
	return &AdminAuthService{repo: repo, sessionTTL: 12 * time.Hour}
}

// SessionTTL is how long a sign-in lasts.
func (s *AdminAuthService) SessionTTL() time.Duration { return s.sessionTTL }

// AdminView is an admin as the panel shows it.
type AdminView struct {
	ID          string     `json:"id"`
	Email       string     `json:"email"`
	Name        string     `json:"name"`
	Role        string     `json:"role"`
	Disabled    bool       `json:"disabled"`
	CreatedAt   time.Time  `json:"createdAt"`
	LastLoginAt *time.Time `json:"lastLoginAt"`
}

func viewOf(a model.AdminUser) AdminView {
	return AdminView{ID: a.ID, Email: a.Email, Name: a.Name, Role: a.Role, Disabled: a.Disabled, CreatedAt: a.CreatedAt, LastLoginAt: a.LastLoginAt}
}

// RoleAtLeast reports whether [role] can do what [need] can.
func RoleAtLeast(role, need string) bool {
	rank := map[string]int{model.RoleViewer: 1, model.RoleEditor: 2, model.RoleOwner: 3}
	return rank[role] >= rank[need]
}

const minPassword = 10

func hashPassword(pw string) (string, error) {
	if len([]rune(pw)) < minPassword {
		return "", domain.Invalid("password must be at least 10 characters")
	}
	if len(pw) > 72 {
		return "", domain.Invalid("password must be at most 72 bytes")
	}
	h, err := bcrypt.GenerateFromPassword([]byte(pw), 12)
	return string(h), err
}

// a real hash, so a wrong email costs the same time as a wrong password
var dummyHash, _ = bcrypt.GenerateFromPassword([]byte("likho-dummy-password"), 12)

func cleanEmail(e string) (string, error) {
	e = strings.ToLower(strings.TrimSpace(e))
	if a, err := mail.ParseAddress(e); err != nil || a.Address != e {
		return "", domain.Invalid("email is not valid")
	}
	return e, nil
}

func validRole(r string) bool {
	return r == model.RoleOwner || r == model.RoleEditor || r == model.RoleViewer
}

// Bootstrap creates the first owner when there are no admins yet.
func (s *AdminAuthService) Bootstrap(ctx context.Context, email, password string) error {
	if email == "" {
		return nil
	}
	n, err := s.repo.CountAdmins(ctx)
	if err != nil || n > 0 {
		return err
	}
	if _, err := s.Create(ctx, email, "Owner", model.RoleOwner, password); err != nil && !errors.Is(err, domain.ErrAdminExists) {
		return err
	}
	slog.Info("admin panel: first owner created", "email", email)
	return nil
}

// Login checks the password and opens a session; the token goes in the
// cookie (only its hash is stored).
func (s *AdminAuthService) Login(ctx context.Context, email, password, userAgent string) (AdminView, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	a, err := s.repo.AdminByEmail(ctx, email)
	if err != nil {
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
		if errors.Is(err, domain.ErrNotFound) {
			return AdminView{}, "", domain.ErrAdminLogin
		}
		return AdminView{}, "", err
	}
	if bcrypt.CompareHashAndPassword([]byte(a.PasswordHash), []byte(password)) != nil || a.Disabled {
		return AdminView{}, "", domain.ErrAdminLogin
	}
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return AdminView{}, "", err
	}
	token := base64.RawURLEncoding.EncodeToString(b)
	if len(userAgent) > 200 {
		userAgent = userAgent[:200]
	}
	err = s.repo.CreateSession(ctx, &model.AdminSession{AdminID: a.ID, TokenHash: hashToken(token), UserAgent: userAgent, ExpiresAt: time.Now().Add(s.sessionTTL)})
	if err != nil {
		return AdminView{}, "", err
	}
	now := time.Now()
	_ = s.repo.UpdateAdmin(ctx, a.ID, map[string]any{"last_login_at": now})
	a.LastLoginAt = &now
	return viewOf(a), token, nil
}

func hashToken(t string) []byte {
	h := sha256.Sum256([]byte("admin:" + t))
	return h[:]
}

// Session returns the admin signed in with [token].
func (s *AdminAuthService) Session(ctx context.Context, token string) (AdminView, error) {
	if token == "" {
		return AdminView{}, domain.ErrAdminSignedOut
	}
	a, _, err := s.repo.SessionAdmin(ctx, hashToken(token))
	if errors.Is(err, domain.ErrNotFound) || (err == nil && a.Disabled) {
		return AdminView{}, domain.ErrAdminSignedOut
	}
	return viewOf(a), err
}

func (s *AdminAuthService) Logout(ctx context.Context, token string) error {
	return s.repo.RevokeSession(ctx, hashToken(token))
}

// ChangePassword changes the signed-in admin's own password (the current
// one is needed) and signs out their other browsers.
func (s *AdminAuthService) ChangePassword(ctx context.Context, adminID, current, next string) error {
	a, err := s.repo.Admin(ctx, adminID)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(a.PasswordHash), []byte(current)) != nil {
		return domain.Invalid("the current password is wrong")
	}
	h, err := hashPassword(next)
	if err != nil {
		return err
	}
	if err := s.repo.UpdateAdmin(ctx, adminID, map[string]any{"password_hash": h}); err != nil {
		return err
	}
	return s.repo.RevokeAdminSessions(ctx, adminID)
}

// ------------------------------------------------------------------ team

func (s *AdminAuthService) Team(ctx context.Context) ([]AdminView, error) {
	all, err := s.repo.Admins(ctx)
	out := make([]AdminView, 0, len(all))
	for _, a := range all {
		out = append(out, viewOf(a))
	}
	return out, err
}

// Create adds an admin with a first password (they can change it).
func (s *AdminAuthService) Create(ctx context.Context, email, name, role, password string) (AdminView, error) {
	email, err := cleanEmail(email)
	if err != nil {
		return AdminView{}, err
	}
	if !validRole(role) {
		return AdminView{}, domain.Invalid("role must be owner, editor or viewer")
	}
	h, err := hashPassword(password)
	if err != nil {
		return AdminView{}, err
	}
	a := model.AdminUser{Email: email, Name: strings.TrimSpace(name), Role: role, PasswordHash: h}
	if err := s.repo.CreateAdmin(ctx, &a); err != nil {
		return AdminView{}, err
	}
	return viewOf(a), nil
}

// AdminPatch changes a team member (owners only).
type AdminPatch struct {
	Name     *string `json:"name"`
	Role     *string `json:"role"`
	Disabled *bool   `json:"disabled"`
	Password *string `json:"password"` // a new first password
}

func (s *AdminAuthService) Update(ctx context.Context, id string, p AdminPatch) (AdminView, error) {
	a, err := s.repo.Admin(ctx, id)
	if err != nil {
		return AdminView{}, err
	}
	updates := map[string]any{}
	if p.Name != nil {
		updates["name"] = strings.TrimSpace(*p.Name)
	}
	losesOwner := false
	if p.Role != nil {
		if !validRole(*p.Role) {
			return AdminView{}, domain.Invalid("role must be owner, editor or viewer")
		}
		updates["role"] = *p.Role
		losesOwner = a.Role == model.RoleOwner && *p.Role != model.RoleOwner
	}
	if p.Disabled != nil {
		updates["disabled"] = *p.Disabled
		losesOwner = losesOwner || (a.Role == model.RoleOwner && *p.Disabled)
	}
	if p.Password != nil {
		h, err := hashPassword(*p.Password)
		if err != nil {
			return AdminView{}, err
		}
		updates["password_hash"] = h
	}
	if losesOwner {
		if n, err := s.repo.OwnersOtherThan(ctx, id); err != nil {
			return AdminView{}, err
		} else if n == 0 {
			return AdminView{}, domain.ErrLastOwner
		}
	}
	if len(updates) > 0 {
		if err := s.repo.UpdateAdmin(ctx, id, updates); err != nil {
			return AdminView{}, err
		}
	}
	if p.Password != nil || (p.Disabled != nil && *p.Disabled) {
		if err := s.repo.RevokeAdminSessions(ctx, id); err != nil {
			return AdminView{}, err
		}
	}
	a, err = s.repo.Admin(ctx, id)
	return viewOf(a), err
}

func (s *AdminAuthService) Delete(ctx context.Context, id string) error {
	a, err := s.repo.Admin(ctx, id)
	if err != nil {
		return err
	}
	if a.Role == model.RoleOwner {
		if n, err := s.repo.OwnersOtherThan(ctx, id); err != nil {
			return err
		} else if n == 0 {
			return domain.ErrLastOwner
		}
	}
	return s.repo.DeleteAdmin(ctx, id)
}
