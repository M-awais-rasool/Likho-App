package repository

import (
	"context"
	"strings"
	"time"

	"gorm.io/gorm"

	"likho/backend/internal/model"
)

// InsightsRepository: read-only numbers and lists for the admin panel
// (families, learners, levels, activity). Progress numbers are for one
// course; the last level of that course says who is "at the end".
type InsightsRepository struct {
	db *gorm.DB
}

// ------------------------------------------------------------- overview

type Totals struct {
	Parents         int64 `json:"parents"`
	Children        int64 `json:"children"`
	NewParents      int64 `json:"newParents"` // in the chosen period
	NewToday        int64 `json:"newToday"`
	ActiveToday     int64 `json:"activeToday"`
	Active7         int64 `json:"active7"`
	Active30        int64 `json:"active30"`
	OnlineNow       int64 `json:"onlineNow"` // seen in the last 5 minutes
	Plus            int64 `json:"plus"`
	TrialsUsed      int64 `json:"trialsUsed"`
	LevelsCompleted int64 `json:"levelsCompleted"` // child x level, first finishes
	StarsEarned     int64 `json:"starsEarned"`     // best stars, summed
	Plays           int64 `json:"plays"`
	LevelsInPeriod  int64 `json:"levelsInPeriod"` // finishes (incl. replays) in the period
	AtEnd           int64 `json:"atEnd"`          // children on the last level
	Finished        int64 `json:"finished"`       // children who finished the course
	Countries       int64 `json:"countries"`
}

type DayPoint struct {
	Day     string `json:"day"`
	Signups int64  `json:"signups"`
	Active  int64  `json:"active"`
	Levels  int64  `json:"levels"`
}

type KeyCount struct {
	Key string `json:"key"`
	N   int64  `json:"n"`
}

type Overview struct {
	Totals    Totals     `json:"totals"`
	Series    []DayPoint `json:"series"`
	Countries []KeyCount `json:"countries"`
	Platforms []KeyCount `json:"platforms"`
	Versions  []KeyCount `json:"versions"`
	Ages      []KeyCount `json:"ages"`
}

// Overview returns the dashboard: totals, a [days]-day series, and how
// families split by country, platform, app version and child age.
func (r *InsightsRepository) Overview(ctx context.Context, courseID string, lastLevel, days int) (Overview, error) {
	db := r.db.WithContext(ctx)
	var o Overview
	// one clock for "today" and the series (UTC days, like active_days)
	today := time.Now().UTC().Truncate(24 * time.Hour)
	since := today.AddDate(0, 0, -(days - 1))
	err := db.Raw(`
		SELECT
		  (SELECT count(*) FROM parents) AS parents,
		  (SELECT count(*) FROM children) AS children,
		  (SELECT count(*) FROM parents WHERE created_at >= @since) AS new_parents,
		  (SELECT count(*) FROM parents WHERE created_at >= @today) AS new_today,
		  (SELECT count(*) FROM active_days WHERE day = CAST(@today AS date)) AS active_today,
		  (SELECT count(DISTINCT parent_id) FROM active_days WHERE day > CAST(@today AS date) - 7) AS active7,
		  (SELECT count(DISTINCT parent_id) FROM active_days WHERE day > CAST(@today AS date) - 30) AS active30,
		  (SELECT count(*) FROM parents WHERE last_seen_at > now() - interval '5 minutes') AS online_now,
		  (SELECT count(*) FROM parents WHERE plus_until > now()) AS plus,
		  (SELECT count(*) FROM parents WHERE trial_used) AS trials_used,
		  (SELECT count(*) FROM level_progress WHERE course_id = @course) AS levels_completed,
		  (SELECT coalesce(sum(best_stars), 0) FROM level_progress WHERE course_id = @course) AS stars_earned,
		  (SELECT coalesce(sum(plays), 0) FROM level_progress WHERE course_id = @course) AS plays,
		  (SELECT count(*) FROM activity_events WHERE type = 'level_completed' AND at >= @since) AS levels_in_period,
		  (SELECT count(*) FROM (SELECT child_id FROM level_progress WHERE course_id = @course GROUP BY child_id
		     HAVING max(level) >= @last - 1 AND max(level) < @last) x) AS at_end,
		  (SELECT count(DISTINCT child_id) FROM level_progress WHERE course_id = @course AND level = @last) AS finished,
		  (SELECT count(DISTINCT country) FROM parents WHERE country <> '') AS countries`,
		map[string]any{"since": since, "today": today, "course": courseID, "last": lastLevel}).Scan(&o.Totals).Error
	if err != nil {
		return o, err
	}

	err = db.Raw(`
		WITH d AS (SELECT generate_series(CAST(@since AS date), CAST(@today AS date), interval '1 day')::date AS day)
		SELECT to_char(d.day, 'YYYY-MM-DD') AS day,
		  (SELECT count(*) FROM parents p WHERE p.created_at >= d.day AND p.created_at < d.day + 1) AS signups,
		  (SELECT count(*) FROM active_days a WHERE a.day = d.day) AS active,
		  (SELECT count(*) FROM activity_events e WHERE e.type = 'level_completed' AND e.at >= d.day AND e.at < d.day + 1) AS levels
		FROM d ORDER BY d.day`, map[string]any{"since": since, "today": today}).Scan(&o.Series).Error
	if err != nil {
		return o, err
	}
	group := func(sql string, out *[]KeyCount) error { return db.Raw(sql).Scan(out).Error }
	if err := group(`SELECT country AS key, count(*) AS n FROM parents GROUP BY country ORDER BY n DESC, key`, &o.Countries); err != nil {
		return o, err
	}
	if err := group(`SELECT platform AS key, count(*) AS n FROM parents GROUP BY platform ORDER BY n DESC, key`, &o.Platforms); err != nil {
		return o, err
	}
	if err := group(`SELECT app_version AS key, count(*) AS n FROM parents WHERE app_version <> '' GROUP BY app_version ORDER BY n DESC, key LIMIT 8`, &o.Versions); err != nil {
		return o, err
	}
	return o, group(`SELECT age::text AS key, count(*) AS n FROM children GROUP BY age ORDER BY age`, &o.Ages)
}

// -------------------------------------------------------------- families

// FamilyRow is a parent account in the families list.
type FamilyRow struct {
	ID            string     `json:"id"`
	Email         string     `json:"email"`
	Name          string     `json:"name"`
	PictureURL    string     `json:"pictureUrl"`
	Country       string     `json:"country"`
	CountrySource string     `json:"countrySource"`
	Platform      string     `json:"platform"`
	AppVersion    string     `json:"appVersion"`
	CreatedAt     time.Time  `json:"createdAt"`
	LastSeenAt    time.Time  `json:"lastSeenAt"`
	PlusUntil     *time.Time `json:"plusUntil"`
	TrialUsed     bool       `json:"trialUsed"`
	Children      int        `json:"children"`
	Stars         int        `json:"stars"`       // stars the children have now
	Levels        int        `json:"levels"`      // levels finished by all children
	StarsEarned   int        `json:"starsEarned"` // best stars, summed
	TopLevel      int        `json:"topLevel"`    // furthest level finished
}

type ListQuery struct {
	Q        string
	Country  string
	Filter   string // families: plus | free | online | active7 | inactive30; learners: new | at_end | finished | active7
	Sort     string
	Desc     bool
	Page     int // from 1
	PageSize int
}

func (q ListQuery) offset() int { return (max(q.Page, 1) - 1) * q.PageSize }

func like(s string) string {
	return "%" + strings.NewReplacer(`\`, `\\`, "%", `\%`, "_", `\_`).Replace(strings.TrimSpace(s)) + "%"
}

func order(sort string, desc bool, allowed map[string]string, def string) string {
	col, ok := allowed[sort]
	if !ok {
		col = def
	}
	if desc {
		return col + " DESC NULLS LAST"
	}
	return col + " ASC NULLS FIRST"
}

const familySelect = `p.id, p.email, p.name, p.picture_url, p.country, p.country_source, p.platform, p.app_version,
	p.created_at, coalesce(p.last_seen_at, p.last_login_at) AS last_seen_at, p.plus_until, p.trial_used,
	coalesce(k.children, 0) AS children, coalesce(k.stars, 0) AS stars,
	coalesce(g.levels, 0) AS levels, coalesce(g.earned, 0) AS stars_earned, coalesce(g.top, 0) AS top_level`

func (r *InsightsRepository) families(ctx context.Context, courseID string, q ListQuery) *gorm.DB {
	db := r.db.WithContext(ctx).Table("parents p")
	if q.Q != "" {
		s := like(q.Q)
		db = db.Where("p.email ILIKE ? OR p.name ILIKE ? OR EXISTS (SELECT 1 FROM children c WHERE c.parent_id = p.id AND c.name ILIKE ?)", s, s, s)
	}
	if q.Country != "" {
		db = db.Where("p.country = ?", strings.ToUpper(q.Country))
	}
	switch q.Filter {
	case "plus":
		db = db.Where("p.plus_until > now()")
	case "free":
		db = db.Where("p.plus_until IS NULL OR p.plus_until <= now()")
	case "online":
		db = db.Where("p.last_seen_at > now() - interval '5 minutes'")
	case "active7":
		db = db.Where("coalesce(p.last_seen_at, p.last_login_at) > now() - interval '7 days'")
	case "inactive30":
		db = db.Where("coalesce(p.last_seen_at, p.last_login_at) <= now() - interval '30 days'")
	}
	return db
}

// Families lists parent accounts with their children's progress in the
// course, and the total that match.
func (r *InsightsRepository) Families(ctx context.Context, courseID string, q ListQuery) ([]FamilyRow, int64, error) {
	var total int64
	if err := r.families(ctx, courseID, q).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	sort := order(q.Sort, q.Desc, map[string]string{
		"lastSeen": "last_seen_at", "created": "p.created_at", "levels": "levels", "stars": "stars_earned",
		"name": "lower(p.name)", "email": "p.email", "children": "children", "country": "p.country",
	}, "last_seen_at")
	var rows []FamilyRow
	err := r.families(ctx, courseID, q).
		Select(familySelect).
		Joins("LEFT JOIN LATERAL (SELECT count(*) AS children, sum(c.stars) AS stars FROM children c WHERE c.parent_id = p.id) k ON true").
		Joins(`LEFT JOIN LATERAL (SELECT count(*) AS levels, sum(lp.best_stars) AS earned, max(lp.level) AS top
			FROM level_progress lp JOIN children c ON c.id = lp.child_id WHERE c.parent_id = p.id AND lp.course_id = ?) g ON true`, courseID).
		Order(sort + ", p.id").Limit(q.PageSize).Offset(q.offset()).
		Scan(&rows).Error
	return rows, total, err
}

// Family returns one parent account as the families list shows it.
func (r *InsightsRepository) Family(ctx context.Context, courseID, parentID string) (FamilyRow, error) {
	var rows []FamilyRow
	err := r.db.WithContext(ctx).Table("parents p").Select(familySelect).
		Joins("LEFT JOIN LATERAL (SELECT count(*) AS children, sum(c.stars) AS stars FROM children c WHERE c.parent_id = p.id) k ON true").
		Joins(`LEFT JOIN LATERAL (SELECT count(*) AS levels, sum(lp.best_stars) AS earned, max(lp.level) AS top
			FROM level_progress lp JOIN children c ON c.id = lp.child_id WHERE c.parent_id = p.id AND lp.course_id = ?) g ON true`, courseID).
		Where("p.id = ?", parentID).Scan(&rows).Error
	if err != nil {
		return FamilyRow{}, err
	}
	if len(rows) == 0 {
		return FamilyRow{}, notFound(gorm.ErrRecordNotFound)
	}
	return rows[0], nil
}

// DeviceSession is a signed-in phone of a parent.
type DeviceSession struct {
	ID        string     `json:"id"`
	Device    string     `json:"device"`
	CreatedAt time.Time  `json:"createdAt"`
	ExpiresAt time.Time  `json:"expiresAt"`
	RevokedAt *time.Time `json:"revokedAt"`
}

func (r *InsightsRepository) Devices(ctx context.Context, parentID string) ([]DeviceSession, error) {
	var out []DeviceSession
	err := r.db.WithContext(ctx).Table("sessions").
		Select("id, device, created_at, expires_at, revoked_at").
		Where("parent_id = ? AND NOT rotated", parentID).
		Order("created_at DESC").Limit(20).Scan(&out).Error
	return out, err
}

// -------------------------------------------------------------- learners

// LearnerRow is a child in the learners list.
type LearnerRow struct {
	ID          string     `json:"id"`
	Name        string     `json:"name"`
	Age         int        `json:"age"`
	Color       string     `json:"color"`
	Stars       int        `json:"stars"`
	CreatedAt   time.Time  `json:"createdAt"`
	ParentID    string     `json:"parentId"`
	ParentEmail string     `json:"parentEmail"`
	ParentName  string     `json:"parentName"`
	Country     string     `json:"country"`
	Platform    string     `json:"platform"`
	Levels      int        `json:"levels"`
	StarsEarned int        `json:"starsEarned"`
	ThreeStars  int        `json:"threeStars"`
	TopLevel    int        `json:"topLevel"`
	LastPlayed  *time.Time `json:"lastPlayed"`
}

func (r *InsightsRepository) learners(ctx context.Context, courseID string, lastLevel int, q ListQuery) *gorm.DB {
	db := r.db.WithContext(ctx).Table("children c").
		Joins("JOIN parents p ON p.id = c.parent_id").
		Joins(`LEFT JOIN LATERAL (SELECT count(*) AS levels, sum(lp.best_stars) AS earned, max(lp.level) AS top,
			max(lp.last_at) AS last_played, count(*) FILTER (WHERE lp.best_stars = 3) AS three
			FROM level_progress lp WHERE lp.child_id = c.id AND lp.course_id = ?) g ON true`, courseID)
	if q.Q != "" {
		s := like(q.Q)
		db = db.Where("c.name ILIKE ? OR p.email ILIKE ? OR p.name ILIKE ?", s, s, s)
	}
	if q.Country != "" {
		db = db.Where("p.country = ?", strings.ToUpper(q.Country))
	}
	switch q.Filter {
	case "new":
		db = db.Where("coalesce(g.top, 0) = 0")
	case "at_end":
		db = db.Where("coalesce(g.top, 0) >= ? AND coalesce(g.top, 0) < ?", lastLevel-1, lastLevel)
	case "finished":
		db = db.Where("coalesce(g.top, 0) >= ?", lastLevel)
	case "active7":
		db = db.Where("g.last_played > now() - interval '7 days'")
	}
	return db
}

// Learners lists children with their progress in the course.
func (r *InsightsRepository) Learners(ctx context.Context, courseID string, lastLevel int, q ListQuery) ([]LearnerRow, int64, error) {
	var total int64
	if err := r.learners(ctx, courseID, lastLevel, q).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	sort := order(q.Sort, q.Desc, map[string]string{
		"levels": "levels", "stars": "stars_earned", "balance": "c.stars", "lastPlayed": "last_played",
		"created": "c.created_at", "name": "lower(c.name)", "age": "c.age", "country": "p.country",
	}, "last_played")
	var rows []LearnerRow
	err := r.learners(ctx, courseID, lastLevel, q).
		Select(`c.id, c.name, c.age, c.color, c.stars, c.created_at, p.id AS parent_id, p.email AS parent_email,
			p.name AS parent_name, p.country, p.platform, coalesce(g.levels, 0) AS levels, coalesce(g.earned, 0) AS stars_earned,
			coalesce(g.three, 0) AS three_stars, coalesce(g.top, 0) AS top_level, g.last_played`).
		Order(sort + ", c.id").Limit(q.PageSize).Offset(q.offset()).
		Scan(&rows).Error
	return rows, total, err
}

// ---------------------------------------------------------------- levels

// LevelStat is how children do on one level.
type LevelStat struct {
	Level      int     `json:"level"`
	Children   int64   `json:"children"` // finished it at least once
	Plays      int64   `json:"plays"`
	AvgStars   float64 `json:"avgStars"`
	ThreeStars int64   `json:"threeStars"`
	OneStar    int64   `json:"oneStar"`
	AvgSeconds float64 `json:"avgSeconds"`
	Current    int64   `json:"current"` // children for whom this is the next level
}

type LevelStats struct {
	Levels   []LevelStat `json:"levels"`
	NotStart int64       `json:"notStarted"` // children who finished no level
	Finished int64       `json:"finished"`   // children who finished the last level
}

// LevelStats returns per-level numbers for levels 1..[lastLevel].
func (r *InsightsRepository) LevelStats(ctx context.Context, courseID string, lastLevel int) (LevelStats, error) {
	db := r.db.WithContext(ctx)
	byLevel := make(map[int]*LevelStat, lastLevel)
	out := LevelStats{Levels: make([]LevelStat, lastLevel)}
	for i := range out.Levels {
		out.Levels[i].Level = i + 1
		byLevel[i+1] = &out.Levels[i]
	}
	var done []LevelStat
	err := db.Raw(`
		SELECT level, count(*) AS children, sum(plays) AS plays, avg(best_stars)::float8 AS avg_stars,
		  count(*) FILTER (WHERE best_stars = 3) AS three_stars, count(*) FILTER (WHERE best_stars = 1) AS one_star
		FROM level_progress WHERE course_id = ? GROUP BY level`, courseID).Scan(&done).Error
	if err != nil {
		return out, err
	}
	for _, d := range done {
		if s, ok := byLevel[d.Level]; ok {
			s.Children, s.Plays, s.AvgStars, s.ThreeStars, s.OneStar = d.Children, d.Plays, d.AvgStars, d.ThreeStars, d.OneStar
		}
	}
	var secs []struct {
		Level int
		Avg   float64
	}
	err = db.Raw(`SELECT level, avg(seconds)::float8 AS avg FROM activity_events
		WHERE type = 'level_completed' AND course_id = ? AND seconds > 0 GROUP BY level`, courseID).Scan(&secs).Error
	if err != nil {
		return out, err
	}
	for _, s := range secs {
		if l, ok := byLevel[s.Level]; ok {
			l.AvgSeconds = s.Avg
		}
	}
	var frontier []struct {
		Top int
		N   int64
	}
	err = db.Raw(`SELECT coalesce(f.top, 0) AS top, count(*) AS n FROM children c
		LEFT JOIN (SELECT child_id, max(level) AS top FROM level_progress WHERE course_id = ? GROUP BY child_id) f ON f.child_id = c.id
		GROUP BY 1`, courseID).Scan(&frontier).Error
	if err != nil {
		return out, err
	}
	for _, f := range frontier {
		switch {
		case f.Top >= lastLevel:
			out.Finished += f.N
		default:
			if f.Top == 0 {
				out.NotStart += f.N
			}
			if l, ok := byLevel[f.Top+1]; ok {
				l.Current += f.N
			}
		}
	}
	return out, nil
}

// -------------------------------------------------------------- activity

// EventRow is an event with who it is about.
type EventRow struct {
	model.ActivityEvent
	ParentEmail string `json:"parentEmail"`
	ParentName  string `json:"parentName"`
	Country     string `json:"country"`
	ChildName   string `json:"childName"`
}

type EventQuery struct {
	Types    []string
	ParentID string
	ChildID  string
	Before   int64 // older than this id (paging back)
	After    int64 // newer than this id (live updates)
	Limit    int
}

// Events returns events, newest first.
func (r *InsightsRepository) Events(ctx context.Context, q EventQuery) ([]EventRow, error) {
	db := r.db.WithContext(ctx).Table("activity_events e").
		Select(`e.*, coalesce(p.email, '') AS parent_email, coalesce(p.name, '') AS parent_name,
			coalesce(p.country, '') AS country, coalesce(c.name, '') AS child_name`).
		Joins("LEFT JOIN parents p ON p.id = e.parent_id").
		Joins("LEFT JOIN children c ON c.id = e.child_id").
		Order("e.id DESC").Limit(q.Limit)
	if len(q.Types) > 0 {
		db = db.Where("e.type IN ?", q.Types)
	}
	if q.ParentID != "" {
		db = db.Where("e.parent_id = ?", q.ParentID)
	}
	if q.ChildID != "" {
		db = db.Where("e.child_id = ?", q.ChildID)
	}
	if q.Before > 0 {
		db = db.Where("e.id < ?", q.Before)
	}
	if q.After > 0 {
		db = db.Where("e.id > ?", q.After)
	}
	var out []EventRow
	return out, db.Scan(&out).Error
}

// ---------------------------------------------------------------- system

// TableSizes counts rows of the main tables (system page).
func (r *InsightsRepository) TableSizes(ctx context.Context) (map[string]int64, error) {
	tables := []string{"parents", "children", "level_progress", "sessions", "activity_events", "active_days", "admin_alerts", "admin_audit", "content_levels"}
	out := make(map[string]int64, len(tables))
	for _, t := range tables {
		var n int64
		if err := r.db.WithContext(ctx).Table(t).Count(&n).Error; err != nil {
			return nil, err
		}
		out[t] = n
	}
	return out, nil
}

// LevelHasProgress reports whether any child finished [level] of the
// course (a level children played cannot be taken away).
func (r *InsightsRepository) LevelHasProgress(ctx context.Context, courseID string, level int) (bool, error) {
	var n int64
	err := r.db.WithContext(ctx).Model(&model.LevelProgress{}).Where("course_id = ? AND level >= ?", courseID, level).Limit(1).Count(&n).Error
	return n > 0, err
}
