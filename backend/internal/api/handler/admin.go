package handler

import (
	"context"
	"encoding/csv"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/api/middleware"
	"likho/backend/internal/domain"
	"likho/backend/internal/repository"
	"likho/backend/internal/service"
)

// AdminHandler is the admin panel's API (/admin/api/v1).
type AdminHandler struct {
	Auth       *service.AdminAuthService
	Admin      *service.AdminService
	Content    *service.ContentService
	ClosedTest *service.ClosedTestService
	Health     *HealthHandler
	Info       SystemInfo
	Secure     bool // cookie only over HTTPS (production)
}

// SystemInfo is shown on the panel's system page.
type SystemInfo struct {
	Env           string    `json:"env"`
	StartedAt     time.Time `json:"startedAt"`
	GeoIP         bool      `json:"geoip"`
	CountryHeader string    `json:"countryHeader"`
	DevLogin      bool      `json:"devLogin"`
}

func actor(c *gin.Context) service.Actor {
	a := middleware.Admin(c)
	return service.Actor{ID: a.ID, Email: a.Email}
}

// writeAdminError adds content problems to the usual error shape.
func writeAdminError(c *gin.Context, err error) {
	var pe *service.ProblemsError
	if errors.As(err, &pe) {
		c.AbortWithStatusJSON(http.StatusUnprocessableEntity, gin.H{"error": "content_invalid", "message": "The level has problems", "problems": pe.Problems})
		return
	}
	writeError(c, err)
}

func (h *AdminHandler) course(c *gin.Context) string {
	if id := c.Query("course"); id != "" && slugRe.MatchString(id) {
		return id
	}
	if cs := h.Content.Courses(); len(cs) > 0 {
		return cs[0].ID
	}
	return ""
}

func intQuery(c *gin.Context, key string, def int) int {
	if v, err := strconv.Atoi(c.Query(key)); err == nil {
		return v
	}
	return def
}

func int64Query(c *gin.Context, key string) int64 {
	v, _ := strconv.ParseInt(c.Query(key), 10, 64)
	return v
}

func listQuery(c *gin.Context) repository.ListQuery {
	return repository.ListQuery{
		Q: c.Query("q"), Country: c.Query("country"), Filter: c.Query("filter"), Sort: c.Query("sort"),
		Desc: c.Query("desc") != "false", Page: max(intQuery(c, "page", 1), 1), PageSize: min(max(intQuery(c, "pageSize", 25), 1), 200),
	}
}

func uuidParam(c *gin.Context, name string) (string, bool) {
	id := c.Param(name)
	if !uuidRe.MatchString(id) {
		writeError(c, domain.ErrNotFound)
		return "", false
	}
	return id, true
}

// ------------------------------------------------------------------ auth

// Login: POST /auth/login {"email", "password"} -> the next step
// {"next": "code" | "setup", "ticket", "secret"?, "otpauthUrl"?}.
func (h *AdminHandler) Login(c *gin.Context) {
	var in struct{ Email, Password string }
	if !bind(c, &in) {
		return
	}
	step, err := h.Auth.Login(c.Request.Context(), in.Email, in.Password)
	if err != nil {
		if errors.Is(err, domain.ErrAdminLocked) || errors.Is(err, domain.ErrAdminLogin) {
			h.Admin.Audit(c.Request.Context(), service.Actor{}, "admin.login_failed", strings.ToLower(strings.TrimSpace(in.Email)), gin.H{"ip": c.ClientIP(), "error": errorCode(err)})
		}
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, step)
}

// Verify: POST /auth/verify {"ticket", "code"} -> sets the session cookie.
func (h *AdminHandler) Verify(c *gin.Context) {
	var in struct{ Ticket, Code string }
	if !bind(c, &in) {
		return
	}
	a, token, setUp, err := h.Auth.Verify(c.Request.Context(), in.Ticket, in.Code, c.GetHeader("User-Agent"))
	if err != nil {
		if errors.Is(err, domain.ErrAdminCode) || errors.Is(err, domain.ErrAdminLocked) {
			h.Admin.Audit(c.Request.Context(), service.Actor{}, "admin.login_failed", "", gin.H{"ip": c.ClientIP(), "error": errorCode(err)})
		}
		writeError(c, err)
		return
	}
	h.setCookie(c, token, int(h.Auth.SessionTTL().Seconds()))
	who := service.Actor{ID: a.ID, Email: a.Email}
	if setUp {
		h.Admin.Audit(c.Request.Context(), who, "admin.two_factor_on", a.Email, nil)
	}
	h.Admin.Audit(c.Request.Context(), who, "admin.login", a.Email, gin.H{"ip": c.ClientIP()})
	writeJSON(c, http.StatusOK, gin.H{"admin": a})
}

func errorCode(err error) string {
	var de *domain.Error
	if errors.As(err, &de) {
		return de.Code
	}
	return "internal"
}

func (h *AdminHandler) setCookie(c *gin.Context, value string, maxAge int) {
	http.SetCookie(c.Writer, &http.Cookie{
		Name: middleware.AdminCookie, Value: value, Path: "/admin", MaxAge: maxAge,
		HttpOnly: true, Secure: h.Secure, SameSite: http.SameSiteStrictMode,
	})
}

// Logout: POST /auth/logout.
func (h *AdminHandler) Logout(c *gin.Context) {
	if token, err := c.Cookie(middleware.AdminCookie); err == nil {
		_ = h.Auth.Logout(c.Request.Context(), token)
	}
	h.setCookie(c, "", -1)
	noContent(c)
}

// Me: GET /auth/me -> the signed-in admin.
func (h *AdminHandler) Me(c *gin.Context) {
	writeJSON(c, http.StatusOK, gin.H{"admin": middleware.Admin(c)})
}

// ChangePassword: POST /auth/password {"current", "next"}.
func (h *AdminHandler) ChangePassword(c *gin.Context) {
	var in struct{ Current, Next string }
	if !bind(c, &in) {
		return
	}
	if err := h.Auth.ChangePassword(c.Request.Context(), middleware.Admin(c).ID, in.Current, in.Next); err != nil {
		writeError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "admin.password_changed", middleware.Admin(c).Email, nil)
	h.setCookie(c, "", -1)
	noContent(c)
}

// ------------------------------------------------------------- dashboard

// Overview: GET /overview?course=&days=30.
func (h *AdminHandler) Overview(c *gin.Context) {
	out, err := h.Admin.Overview(c.Request.Context(), h.course(c), intQuery(c, "days", 30))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// -------------------------------------------------------------- families

// Families: GET /families?q=&country=&filter=&sort=&desc=&page=&pageSize=.
func (h *AdminHandler) Families(c *gin.Context) {
	out, err := h.Admin.Families(c.Request.Context(), h.course(c), listQuery(c))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// FamiliesCSV: GET /families.csv (same filters, every match).
func (h *AdminHandler) FamiliesCSV(c *gin.Context) {
	q := listQuery(c)
	q.Page, q.PageSize = 1, 50000
	out, err := h.Admin.Families(c.Request.Context(), h.course(c), q)
	if err != nil {
		writeError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "families.exported", "", gin.H{"rows": len(out.Items), "q": q.Q, "country": q.Country, "filter": q.Filter})
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="likho-families-%s.csv"`, time.Now().Format("2006-01-02")))
	w := csv.NewWriter(c.Writer)
	_ = w.Write([]string{"id", "email", "name", "country", "platform", "app_version", "joined", "last_seen", "plus_until", "children", "levels_completed", "stars_earned", "top_level"})
	for _, f := range out.Items {
		plus := ""
		if f.PlusUntil != nil {
			plus = f.PlusUntil.UTC().Format(time.RFC3339)
		}
		_ = w.Write([]string{f.ID, csvSafe(f.Email), csvSafe(f.Name), f.Country, f.Platform, f.AppVersion,
			f.CreatedAt.UTC().Format(time.RFC3339), f.LastSeenAt.UTC().Format(time.RFC3339), plus,
			strconv.Itoa(f.Children), strconv.Itoa(f.Levels), strconv.Itoa(f.StarsEarned), strconv.Itoa(f.TopLevel)})
	}
	w.Flush()
}

// csvSafe stops spreadsheet apps from running a cell as a formula.
func csvSafe(s string) string {
	if s != "" && strings.ContainsRune("=+-@\t\r", rune(s[0])) {
		return "'" + s
	}
	return s
}

// Family: GET /families/:parentId.
func (h *AdminHandler) Family(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	out, err := h.Admin.Family(c.Request.Context(), h.course(c), id)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// GrantPlus: POST /families/:parentId/plus {"days"}.
func (h *AdminHandler) GrantPlus(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	var in struct{ Days int }
	if !bind(c, &in) {
		return
	}
	out, err := h.Admin.GrantPlus(c.Request.Context(), actor(c), id, in.Days)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// RevokePlus: DELETE /families/:parentId/plus.
func (h *AdminHandler) RevokePlus(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	out, err := h.Admin.RevokePlus(c.Request.Context(), actor(c), id)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// SignOut: POST /families/:parentId/sign-out.
func (h *AdminHandler) SignOut(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	if err := h.Admin.SignOutEverywhere(c.Request.Context(), actor(c), id); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

// DeleteFamily: DELETE /families/:parentId.
func (h *AdminHandler) DeleteFamily(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	if err := h.Admin.DeleteFamily(c.Request.Context(), actor(c), id); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

// AdjustStars: POST /children/:childId/stars {"delta", "reason"}.
func (h *AdminHandler) AdjustStars(c *gin.Context) {
	id, ok := uuidParam(c, "childId")
	if !ok {
		return
	}
	var in struct {
		Delta  int
		Reason string
	}
	if !bind(c, &in) {
		return
	}
	stars, err := h.Admin.AdjustStars(c.Request.Context(), actor(c), id, in.Delta, truncate(in.Reason, 200))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"stars": stars})
}

// Learners: GET /learners (same paging as families).
func (h *AdminHandler) Learners(c *gin.Context) {
	out, err := h.Admin.Learners(c.Request.Context(), h.course(c), listQuery(c))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// LevelStats: GET /levels/stats.
func (h *AdminHandler) LevelStats(c *gin.Context) {
	out, err := h.Admin.LevelStats(c.Request.Context(), h.course(c))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// Activity: GET /activity?types=a,b&parentId=&childId=&before=&after=&limit=.
func (h *AdminHandler) Activity(c *gin.Context) {
	q := repository.EventQuery{Before: int64Query(c, "before"), After: int64Query(c, "after"), Limit: intQuery(c, "limit", 50)}
	if t := c.Query("types"); t != "" {
		q.Types = strings.Split(t, ",")
	}
	if id := c.Query("parentId"); uuidRe.MatchString(id) {
		q.ParentID = id
	}
	if id := c.Query("childId"); uuidRe.MatchString(id) {
		q.ChildID = id
	}
	out, err := h.Admin.Events(c.Request.Context(), q)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"items": out})
}

// ---------------------------------------------------------------- alerts

// Alerts: GET /alerts?unread=1&before=&limit=.
func (h *AdminHandler) Alerts(c *gin.Context) {
	out, err := h.Admin.Alerts(c.Request.Context(), c.Query("unread") == "1", int64Query(c, "before"), intQuery(c, "limit", 50))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"items": out})
}

// UnreadAlerts: GET /alerts/unread -> {"count", "latest"} (polled by the panel).
func (h *AdminHandler) UnreadAlerts(c *gin.Context) {
	n, latest, err := h.Admin.UnreadAlerts(c.Request.Context())
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"count": n, "latest": latest})
}

// ReadAlerts: POST /alerts/read {"ids": [..]} (no ids = all).
func (h *AdminHandler) ReadAlerts(c *gin.Context) {
	var in struct{ IDs []int64 }
	if !bind(c, &in) {
		return
	}
	if err := h.Admin.MarkAlertsRead(c.Request.Context(), actor(c), in.IDs); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}

// AlertRules: GET /settings/alerts.
func (h *AdminHandler) AlertRules(c *gin.Context) {
	writeJSON(c, http.StatusOK, h.Admin.AlertRules(c.Request.Context()))
}

// SetAlertRules: PUT /settings/alerts.
func (h *AdminHandler) SetAlertRules(c *gin.Context) {
	var in service.AlertRules
	if !bind(c, &in) {
		return
	}
	out, err := h.Admin.SetAlertRules(c.Request.Context(), actor(c), in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// --------------------------------------------------------------- content

func levelNumber(c *gin.Context) (int, bool) {
	n, err := strconv.Atoi(c.Param("number"))
	if err != nil || n < 1 || n > 999 {
		writeError(c, domain.ErrNotFound)
		return 0, false
	}
	return n, true
}

// Courses: GET /courses -> the served courses (the panel picks one).
func (h *AdminHandler) Courses(c *gin.Context) {
	writeJSON(c, http.StatusOK, gin.H{"courses": h.Content.Courses()})
}

// ContentCourse: GET /content/courses/:courseId.
func (h *AdminHandler) ContentCourse(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	out, err := h.Content.Course(c.Request.Context(), id)
	if err != nil {
		writeAdminError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// ContentDocument: GET /content/courses/:courseId/document -> the course
// with every working copy (for the phone preview).
func (h *AdminHandler) ContentDocument(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	body, err := h.Content.StagedDocument(c.Request.Context(), id)
	if err != nil {
		writeAdminError(c, err)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

// ContentLevel: GET /content/courses/:courseId/levels/:number.
func (h *AdminHandler) ContentLevel(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	n, ok := levelNumber(c)
	if !ok {
		return
	}
	out, err := h.Content.Level(c.Request.Context(), id, n)
	if err != nil {
		writeAdminError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

type levelInput struct {
	Number int    `json:"number"`
	World  string `json:"world"`
	Doc    string `json:"doc"`
}

// ValidateLevel: POST /content/courses/:courseId/levels/validate
// {"number", "world", "doc"} -> {"ok": true} or 422 with the problems.
func (h *AdminHandler) ValidateLevel(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	var in levelInput
	if !bind(c, &in) {
		return
	}
	if err := h.Content.Validate(c.Request.Context(), id, in.Number, in.World, in.Doc); err != nil {
		writeAdminError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"ok": true})
}

// SaveLevel: POST /content/courses/:courseId/levels {"number", "world",
// "doc"} (a new level) or PUT …/levels/:number {"doc"} (an edit).
func (h *AdminHandler) SaveLevel(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	var in levelInput
	if !bind(c, &in) {
		return
	}
	created := c.Request.Method == http.MethodPost
	if !created {
		n, ok := levelNumber(c)
		if !ok {
			return
		}
		in.Number, in.World = n, ""
	}
	out, err := h.Content.SaveLevel(c.Request.Context(), id, in.Number, in.World, in.Doc, middleware.Admin(c).Email)
	if err != nil {
		writeAdminError(c, err)
		return
	}
	action := "content.level_saved"
	if created {
		action = "content.level_created"
	}
	h.Admin.Audit(c.Request.Context(), actor(c), action, fmt.Sprintf("%s#%d", id, in.Number), gin.H{"name": out.Name, "world": out.World})
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(c, status, out)
}

// LevelAction: POST /content/courses/:courseId/levels/:number/{publish|unpublish|discard}.
func (h *AdminHandler) LevelAction(action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, ok := courseID(c)
		if !ok {
			return
		}
		n, ok := levelNumber(c)
		if !ok {
			return
		}
		ctx, by := c.Request.Context(), middleware.Admin(c).Email
		var out service.ContentLevelDetail
		var err error
		switch action {
		case "publish":
			out, err = h.Content.Publish(ctx, id, n, by)
		case "unpublish":
			out, err = h.Content.Unpublish(ctx, id, n)
		case "discard":
			out, err = h.Content.Discard(ctx, id, n, by)
		}
		if err != nil {
			writeAdminError(c, err)
			return
		}
		h.Admin.Audit(ctx, actor(c), "content.level_"+action+"ed", fmt.Sprintf("%s#%d", id, n), gin.H{"name": out.Name})
		writeJSON(c, http.StatusOK, out)
	}
}

// DeleteLevel: DELETE /content/courses/:courseId/levels/:number.
func (h *AdminHandler) DeleteLevel(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	n, ok := levelNumber(c)
	if !ok {
		return
	}
	if err := h.Content.Delete(c.Request.Context(), id, n); err != nil {
		writeAdminError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "content.level_deleted", fmt.Sprintf("%s#%d", id, n), nil)
	noContent(c)
}

// CreateWorld: POST /content/courses/:courseId/worlds; UpdateWorld: PUT
// …/worlds/:folder.
func (h *AdminHandler) SaveWorld(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	var in service.WorldInput
	if !bind(c, &in) {
		return
	}
	var out service.ContentWorldView
	var err error
	if c.Request.Method == http.MethodPost {
		out, err = h.Content.CreateWorld(c.Request.Context(), id, in, middleware.Admin(c).Email)
	} else {
		out, err = h.Content.UpdateWorld(c.Request.Context(), id, c.Param("folder"), in)
	}
	if err != nil {
		writeAdminError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "content.world_saved", id+"/"+out.Folder, in)
	writeJSON(c, http.StatusOK, out)
}

// DeleteWorld: DELETE /content/courses/:courseId/worlds/:folder.
func (h *AdminHandler) DeleteWorld(c *gin.Context) {
	id, ok := courseID(c)
	if !ok {
		return
	}
	if err := h.Content.DeleteWorld(c.Request.Context(), id, c.Param("folder")); err != nil {
		writeAdminError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "content.world_deleted", id+"/"+c.Param("folder"), nil)
	noContent(c)
}

// ------------------------------------------------------------------ team

// Team: GET /team.
func (h *AdminHandler) Team(c *gin.Context) {
	out, err := h.Auth.Team(c.Request.Context())
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"items": out})
}

// AddAdmin: POST /team {"email", "name", "role", "password"}.
func (h *AdminHandler) AddAdmin(c *gin.Context) {
	var in struct{ Email, Name, Role, Password string }
	if !bind(c, &in) {
		return
	}
	out, err := h.Auth.Create(c.Request.Context(), in.Email, in.Name, in.Role, in.Password)
	if err != nil {
		writeError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "team.added", out.Email, gin.H{"role": out.Role})
	writeJSON(c, http.StatusCreated, out)
}

// UpdateAdmin: PATCH /team/:id.
func (h *AdminHandler) UpdateAdmin(c *gin.Context) {
	id, ok := uuidParam(c, "id")
	if !ok {
		return
	}
	var in service.AdminPatch
	if !bind(c, &in) {
		return
	}
	out, err := h.Auth.Update(c.Request.Context(), id, in)
	if err != nil {
		writeError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "team.updated", out.Email, gin.H{"role": in.Role, "disabled": in.Disabled, "name": in.Name, "passwordReset": in.Password != nil, "twoFactorReset": in.ResetTwoFactor})
	writeJSON(c, http.StatusOK, out)
}

// DeleteAdmin: DELETE /team/:id.
func (h *AdminHandler) DeleteAdmin(c *gin.Context) {
	id, ok := uuidParam(c, "id")
	if !ok {
		return
	}
	if id == middleware.Admin(c).ID {
		writeError(c, domain.Invalid("you cannot remove yourself"))
		return
	}
	if err := h.Auth.Delete(c.Request.Context(), id); err != nil {
		writeError(c, err)
		return
	}
	h.Admin.Audit(c.Request.Context(), actor(c), "team.removed", id, nil)
	noContent(c)
}

// Audit: GET /audit?before=&limit=.
func (h *AdminHandler) Audit(c *gin.Context) {
	out, err := h.Admin.AuditLog(c.Request.Context(), int64Query(c, "before"), min(max(intQuery(c, "limit", 50), 1), 200))
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"items": out})
}

// System: GET /system -> health, versions, content and table sizes.
func (h *AdminHandler) System(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	check := func(p interface{ Ping(context.Context) error }) gin.H {
		start := time.Now()
		if err := p.Ping(ctx); err != nil {
			return gin.H{"ok": false, "error": err.Error()}
		}
		return gin.H{"ok": true, "ms": float64(time.Since(start).Microseconds()) / 1000}
	}
	sizes, err := h.Admin.TableSizes(ctx)
	if err != nil {
		writeError(c, err)
		return
	}
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	writeJSON(c, http.StatusOK, gin.H{
		"info":     h.Info,
		"uptime":   time.Since(h.Info.StartedAt).Round(time.Second).String(),
		"go":       runtime.Version(),
		"memoryMb": mem.Alloc / (1 << 20),
		"postgres": check(h.Health.Postgres),
		"redis":    check(h.Health.Redis),
		"content":  gin.H{"revision": h.Content.Revision(), "problems": h.Content.Problems(), "courses": h.Content.Courses()},
		"tables":   sizes,
	})
}
