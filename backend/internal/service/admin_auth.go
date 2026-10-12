package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
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

// AdminAuthService: signing in to the admin panel (email + password, then
// a code from an authenticator app; a random session token in an HttpOnly
// cookie) and the team of admins.
type AdminAuthService struct {
	repo       *repository.AdminRepository
	store      AdminLoginStore
	sessionTTL time.Duration
	now        func() time.Time
}

// AdminLoginStore keeps the step between the password and the code, and
// counts wrong tries per account (Redis: cache.Cache).
type AdminLoginStore interface {
	PutLoginTicket(ctx context.Context, id string, v []byte, ttl time.Duration) error
	LoginTicket(ctx context.Context, id string) ([]byte, bool, error)
	DropLoginTicket(ctx context.Context, id string)
	LoginFailures(ctx context.Context, email string) int64
	AddLoginFailure(ctx context.Context, email string, window time.Duration) int64
	ClearLoginFailures(ctx context.Context, email string)
}

const (
	// wrong passwords or codes (from any IP) before an account is locked,
	// and how long the lock lasts after the last one
	adminMaxFailures = 5
	adminLockFor     = 15 * time.Minute
	// time to type the code (or set up the app) after the password
	adminTicketTTL = 10 * time.Minute
)

func NewAdminAuthService(repo *repository.AdminRepository, store AdminLoginStore) *AdminAuthService {
	return &AdminAuthService{repo: repo, store: store, sessionTTL: 12 * time.Hour, now: time.Now}
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
	TwoFactor   bool       `json:"twoFactor"` // the authenticator app is set up
}

func viewOf(a model.AdminUser) AdminView {
	return AdminView{ID: a.ID, Email: a.Email, Name: a.Name, Role: a.Role, Disabled: a.Disabled, CreatedAt: a.CreatedAt, LastLoginAt: a.LastLoginAt, TwoFactor: a.TOTPSecret != ""}
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

// LoginStep is what the panel asks after a right password: the code from
// the authenticator app ("code"), or to set the app up first ("setup":
// scan [URL] as a QR code, or type [Secret]). [Ticket] goes with the code.
type LoginStep struct {
	Next   string `json:"next"`
	Ticket string `json:"ticket"`
	Secret string `json:"secret,omitempty"`
	URL    string `json:"otpauthUrl,omitempty"`
}

// loginTicket is kept between the two steps (only its id goes out).
type loginTicket struct {
	AdminID string `json:"adminId"`
	Email   string `json:"email"`
	Secret  string `json:"secret,omitempty"` // a new secret, until its first code
}

// Login checks the password (step 1). Wrong tries count against the
// account; after adminMaxFailures it is locked for adminLockFor.
func (s *AdminAuthService) Login(ctx context.Context, email, password string) (LoginStep, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if s.store.LoginFailures(ctx, email) >= adminMaxFailures {
		return LoginStep{}, domain.ErrAdminLocked
	}
	a, err := s.repo.AdminByEmail(ctx, email)
	if err != nil {
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
		if errors.Is(err, domain.ErrNotFound) {
			s.store.AddLoginFailure(ctx, email, adminLockFor)
			return LoginStep{}, domain.ErrAdminLogin
		}
		return LoginStep{}, err
	}
	if bcrypt.CompareHashAndPassword([]byte(a.PasswordHash), []byte(password)) != nil || a.Disabled {
		s.store.AddLoginFailure(ctx, email, adminLockFor)
		return LoginStep{}, domain.ErrAdminLogin
	}
	t := loginTicket{AdminID: a.ID, Email: a.Email}
	step := LoginStep{Next: "code"}
	if a.TOTPSecret == "" {
		if t.Secret, err = NewTOTPSecret(); err != nil {
			return LoginStep{}, err
		}
		step = LoginStep{Next: "setup", Secret: t.Secret, URL: TOTPURL(t.Secret, a.Email)}
	}
	if step.Ticket, err = randomToken(); err != nil {
		return LoginStep{}, err
	}
	v, _ := json.Marshal(t)
	if err := s.store.PutLoginTicket(ctx, ticketID(step.Ticket), v, adminTicketTTL); err != nil {
		return LoginStep{}, err
	}
	return step, nil
}

// Verify checks the authenticator code for [ticket] (step 2) and opens a
// session; the token goes in the cookie (only its hash is stored). The
// first right code after "setup" turns two-step sign-in on (setUp).
func (s *AdminAuthService) Verify(ctx context.Context, ticket, code, userAgent string) (view AdminView, token string, setUp bool, err error) {
	raw, ok, err := s.store.LoginTicket(ctx, ticketID(ticket))
	if err != nil {
		return AdminView{}, "", false, err
	}
	var t loginTicket
	if !ok || json.Unmarshal(raw, &t) != nil {
		return AdminView{}, "", false, domain.ErrAdminTicket
	}
	if s.store.LoginFailures(ctx, t.Email) >= adminMaxFailures {
		s.store.DropLoginTicket(ctx, ticketID(ticket))
		return AdminView{}, "", false, domain.ErrAdminLocked
	}
	a, err := s.repo.Admin(ctx, t.AdminID)
	if errors.Is(err, domain.ErrNotFound) || (err == nil && a.Disabled) {
		return AdminView{}, "", false, domain.ErrAdminTicket
	}
	if err != nil {
		return AdminView{}, "", false, err
	}
	secret, last := a.TOTPSecret, a.TOTPLastStep
	if t.Secret != "" {
		secret, last = t.Secret, 0
	}
	if secret == "" { // reset since step 1
		return AdminView{}, "", false, domain.ErrAdminTicket
	}
	step, ok := checkTOTP(secret, code, s.now(), last)
	if !ok {
		s.store.AddLoginFailure(ctx, t.Email, adminLockFor)
		return AdminView{}, "", false, domain.ErrAdminCode
	}
	// only the first of two tabs with the same code gets in
	q := map[string]any{"totp_secret": secret, "totp_last_step": step}
	if n, err := s.repo.UseTOTPStep(ctx, a.ID, a.TOTPSecret, last, q); err != nil {
		return AdminView{}, "", false, err
	} else if n == 0 {
		s.store.AddLoginFailure(ctx, t.Email, adminLockFor)
		return AdminView{}, "", false, domain.ErrAdminCode
	}
	s.store.DropLoginTicket(ctx, ticketID(ticket))
	s.store.ClearLoginFailures(ctx, t.Email)

	if token, err = randomToken(); err != nil {
		return AdminView{}, "", false, err
	}
	if len(userAgent) > 200 {
		userAgent = userAgent[:200]
	}
	err = s.repo.CreateSession(ctx, &model.AdminSession{AdminID: a.ID, TokenHash: hashToken(token), UserAgent: userAgent, ExpiresAt: s.now().Add(s.sessionTTL)})
	if err != nil {
		return AdminView{}, "", false, err
	}
	now := s.now()
	_ = s.repo.UpdateAdmin(ctx, a.ID, map[string]any{"last_login_at": now})
	a.LastLoginAt, a.TOTPSecret = &now, secret
	return viewOf(a), token, t.Secret != "", nil
}

// ResetTwoFactor makes [email] set up the authenticator app again at the
// next sign-in (a lost phone), signs them out and lifts a lock. For the
// server command (owners use Update in the panel).
func (s *AdminAuthService) ResetTwoFactor(ctx context.Context, email string) error {
	a, err := s.repo.AdminByEmail(ctx, strings.ToLower(strings.TrimSpace(email)))
	if err != nil {
		return err
	}
	if err := s.repo.UpdateAdmin(ctx, a.ID, map[string]any{"totp_secret": "", "totp_last_step": 0}); err != nil {
		return err
	}
	s.store.ClearLoginFailures(ctx, a.Email)
	return s.repo.RevokeAdminSessions(ctx, a.ID)
}

func randomToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// ticketID is what Redis keeps for a ticket (not the ticket itself).
func ticketID(ticket string) string {
	h := sha256.Sum256([]byte("admin-ticket:" + ticket))
	return hex.EncodeToString(h[:])
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
	// without the authenticator app (a session from before two-step
	// sign-in, or the app was reset since) the session does not count
	if errors.Is(err, domain.ErrNotFound) || (err == nil && (a.Disabled || a.TOTPSecret == "")) {
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
	// set up the authenticator app again at the next sign-in (lost phone)
	ResetTwoFactor bool `json:"resetTwoFactor"`
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
	if p.ResetTwoFactor {
		updates["totp_secret"], updates["totp_last_step"] = "", 0
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
	if p.Password != nil || p.ResetTwoFactor || (p.Disabled != nil && *p.Disabled) {
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
