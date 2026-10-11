// Package model holds the data shapes: entity.go = database tables (GORM),
// dto.go = the JSON the API sends and receives.
package model

import (
	"time"

	"likho/backend/internal/domain"
)

// Database tables. GORM creates and updates them from these structs at
// start-up (database.Migrate); the tags carry the constraints and indexes.

// Parent is the account: one Google user. Children never sign in.
type Parent struct {
	ID         string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	GoogleSub  string `gorm:"uniqueIndex;not null"` // Google's stable user id
	Email      string `gorm:"not null"`
	Name       string `gorm:"not null;default:''"`
	PictureURL string `gorm:"not null;default:''"`

	// Settings screen
	SessionMinutes int  `gorm:"type:smallint;not null;default:10;check:session_minutes IN (5, 10, 15)"`
	Music          bool `gorm:"not null;default:true"`
	Sfx            bool `gorm:"not null;default:true"`
	Haptics        bool `gorm:"not null;default:true"`
	LeftHanded     bool `gorm:"not null;default:false"`
	ReduceMotion   bool `gorm:"not null;default:false"`

	// Likho Plus: trial or paid access ends at PlusUntil
	PlusUntil *time.Time
	TrialUsed bool `gorm:"not null;default:false"`

	// Tester: a test account; every level is open (set in the database or
	// the admin panel, never by the app).
	Tester bool `gorm:"not null;default:false"`

	CreatedAt   time.Time
	LastLoginAt time.Time `gorm:"not null;default:now()"`

	// Where and how the family uses Likho (admin panel). Kept up to date
	// at most every few minutes; no IP address is stored.
	LastSeenAt    *time.Time `gorm:"index"`
	Country       string     `gorm:"type:varchar(2);not null;default:'';index"` // ISO 3166-1 alpha-2, "" = unknown
	CountrySource string     `gorm:"type:varchar(8);not null;default:''"`       // cdn | ip | device
	Platform      string     `gorm:"type:varchar(16);not null;default:''"`      // ios | android | web
	AppVersion    string     `gorm:"type:varchar(32);not null;default:''"`

	Children   []Child         `gorm:"constraint:OnDelete:CASCADE"`
	Sessions   []Session       `gorm:"constraint:OnDelete:CASCADE"`
	Events     []ActivityEvent `gorm:"constraint:OnDelete:CASCADE"`
	ActiveDays []ActiveDay     `gorm:"constraint:OnDelete:CASCADE"`
	Alerts     []AdminAlert    `gorm:"constraint:OnDelete:CASCADE"`

	PlaySubscriptions []PlaySubscription `gorm:"constraint:OnDelete:CASCADE"`

	// Google Play closed test (admin panel)
	TestAccount *ClosedTestAccount `gorm:"constraint:OnDelete:CASCADE"`
	TestDays    []ClosedTestDay    `gorm:"constraint:OnDelete:CASCADE"`
}

func (p Parent) PlusActive(now time.Time) bool { return p.PlusUntil != nil && p.PlusUntil.After(now) }

// Child is one of up to 4 profiles under a parent.
type Child struct {
	ID        string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	ParentID  string    `gorm:"type:uuid;not null;index:idx_children_parent,priority:1"`
	Name      string    `gorm:"not null;check:char_length(name) BETWEEN 1 AND 14"`
	Age       int       `gorm:"type:smallint;not null;check:age BETWEEN 5 AND 8"`
	Color     string    `gorm:"not null"` // Pencil colour, e.g. "#FFC83D"
	Stars     int       `gorm:"not null;default:0;check:stars >= 0"`
	Wearing   *string   // shop item id Pencil wears
	CreatedAt time.Time `gorm:"index:idx_children_parent,priority:2"`
	UpdatedAt time.Time

	Progress []LevelProgress `gorm:"constraint:OnDelete:CASCADE"`
	Items    []ChildItem     `gorm:"constraint:OnDelete:CASCADE"`
	PlayDays []PlayDay       `gorm:"constraint:OnDelete:CASCADE"`
}

// LevelProgress is a child's best result on one level of one course. Each
// child has their own progress in every course.
type LevelProgress struct {
	ChildID   string    `gorm:"type:uuid;primaryKey"`
	CourseID  string    `gorm:"type:varchar(64);primaryKey"`
	Level     int       `gorm:"type:smallint;primaryKey;autoIncrement:false;check:level >= 1"`
	BestStars int       `gorm:"type:smallint;not null;check:best_stars BETWEEN 1 AND 3"`
	Plays     int       `gorm:"not null;default:1"`
	FirstAt   time.Time `gorm:"not null;default:now()"`
	LastAt    time.Time `gorm:"not null;default:now()"`
}

func (LevelProgress) TableName() string { return "level_progress" }

// ChildItem is something bought in the Mascot Room. Furniture can be
// placed in the room.
type ChildItem struct {
	ChildID  string    `gorm:"type:uuid;primaryKey"`
	ItemID   string    `gorm:"primaryKey"`
	Placed   bool      `gorm:"not null;default:false"`
	BoughtAt time.Time `gorm:"not null;default:now()"`
}

// PlayDay is one row per child per day played (days played, minutes this
// week).
type PlayDay struct {
	ChildID string    `gorm:"type:uuid;primaryKey"`
	Day     time.Time `gorm:"type:date;primaryKey"`
	Seconds int       `gorm:"not null;default:0"`
	Levels  int       `gorm:"not null;default:0"`
}

// Session is one signed-in device. Only a SHA-256 hash of the refresh token
// is stored.
type Session struct {
	ID        string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	ParentID  string `gorm:"type:uuid;not null;index:idx_sessions_active,where:revoked_at IS NULL"`
	TokenHash []byte `gorm:"uniqueIndex;not null"`
	Device    string `gorm:"not null;default:''"`
	CreatedAt time.Time
	ExpiresAt time.Time `gorm:"not null"`
	RevokedAt *time.Time
	Rotated   bool `gorm:"not null;default:false"` // revoked because it was swapped for a new token
}

// ActivityEvent is one thing a family did (signed up, finished a level…),
// for the admin panel's activity feed and charts. Deleting the account
// deletes its events.
type ActivityEvent struct {
	ID       int64     `gorm:"primaryKey" json:"id"`
	At       time.Time `gorm:"not null;default:now();index;index:idx_events_type_at,priority:2" json:"at"`
	Type     string    `gorm:"type:varchar(32);not null;index:idx_events_type_at,priority:1" json:"type"`
	ParentID *string   `gorm:"type:uuid;index" json:"parentId"`
	ChildID  *string   `gorm:"type:uuid;index" json:"childId"`
	CourseID string    `gorm:"type:varchar(64);not null;default:''" json:"courseId"`
	Level    int       `gorm:"type:smallint;not null;default:0" json:"level"`
	Stars    int       `gorm:"type:smallint;not null;default:0" json:"stars"`
	Seconds  int       `gorm:"not null;default:0" json:"seconds"`
	Detail   JSON      `gorm:"type:jsonb;not null;default:'{}'" json:"detail"`
}

// Activity event types.
const (
	EventSignedUp        = "signed_up"
	EventSignedIn        = "signed_in"
	EventChildAdded      = "child_added"
	EventChildRemoved    = "child_removed"
	EventLevelCompleted  = "level_completed"
	EventCourseCompleted = "course_completed"
	EventItemBought      = "item_bought"
	EventTrialStarted    = "trial_started"
	EventPlusPurchased   = "plus_purchased"
	EventAccountDeleted  = "account_deleted"
)

// ActiveDay is one row per parent per day the app was used (daily, weekly
// and monthly active users).
type ActiveDay struct {
	ParentID string    `gorm:"type:uuid;primaryKey"`
	Day      time.Time `gorm:"type:date;primaryKey;index"`
}

// AdminUser can sign in to the admin panel (email + password; separate
// from the parents' Google accounts).
type AdminUser struct {
	ID           string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	Email        string `gorm:"uniqueIndex;not null"`
	Name         string `gorm:"not null;default:''"`
	PasswordHash string `gorm:"not null"`
	Role         string `gorm:"type:varchar(16);not null;default:'viewer';check:role IN ('owner', 'editor', 'viewer')"`
	Disabled     bool   `gorm:"not null;default:false"`
	CreatedAt    time.Time
	LastLoginAt  *time.Time

	Sessions []AdminSession `gorm:"foreignKey:AdminID;constraint:OnDelete:CASCADE"`
}

// Admin roles: viewers read, editors also change content and accounts,
// owners also manage the team.
const (
	RoleOwner  = "owner"
	RoleEditor = "editor"
	RoleViewer = "viewer"
)

// AdminSession is one signed-in browser (a hash of the cookie is stored).
type AdminSession struct {
	ID        string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	AdminID   string `gorm:"type:uuid;not null;index"`
	TokenHash []byte `gorm:"uniqueIndex;not null"`
	UserAgent string `gorm:"not null;default:''"`
	CreatedAt time.Time
	ExpiresAt time.Time `gorm:"not null"`
	RevokedAt *time.Time
}

// AdminAlert is something the team should know about, e.g. a child who
// reached the last level (time to add more). Each happens once (Key).
type AdminAlert struct {
	ID       int64      `gorm:"primaryKey" json:"id"`
	At       time.Time  `gorm:"not null;default:now();index" json:"at"`
	Kind     string     `gorm:"type:varchar(32);not null;index" json:"kind"`
	Key      string     `gorm:"uniqueIndex;not null" json:"-"`
	ParentID *string    `gorm:"type:uuid;index" json:"parentId"`
	ChildID  *string    `gorm:"type:uuid" json:"childId"`
	CourseID string     `gorm:"type:varchar(64);not null;default:''" json:"courseId"`
	Level    int        `gorm:"type:smallint;not null;default:0" json:"level"`
	Title    string     `gorm:"not null" json:"title"`
	Body     string     `gorm:"not null;default:''" json:"body"`
	ReadAt   *time.Time `gorm:"index" json:"readAt"`
	ReadBy   string     `gorm:"not null;default:''" json:"readBy"`
}

// Alert kinds.
const (
	AlertReachedEnd      = "reached_end"      // a child is on the last level(s)
	AlertCourseCompleted = "course_completed" // a child finished every level
	AlertNewSignup       = "new_signup"
	AlertTrialStarted    = "trial_started"
)

// AuditEntry records every change made in the admin panel.
type AuditEntry struct {
	ID         int64     `gorm:"primaryKey" json:"id"`
	At         time.Time `gorm:"not null;default:now();index" json:"at"`
	AdminID    string    `gorm:"type:uuid;index" json:"adminId"`
	AdminEmail string    `gorm:"not null" json:"adminEmail"`
	Action     string    `gorm:"type:varchar(48);not null;index" json:"action"`
	Target     string    `gorm:"not null;default:''" json:"target"`
	Detail     JSON      `gorm:"type:jsonb;not null;default:'{}'" json:"detail"`
}

func (AuditEntry) TableName() string { return "admin_audit" }

// ContentLevel is a level written in the admin panel: a new level (after
// the ones in content/) or an edit of one of them. Doc is the working copy
// (JSON text, as authored); LiveDoc is what phones get (nil = not
// published). Both are checked like the files in content/.
type ContentLevel struct {
	CourseID    string  `gorm:"type:varchar(64);primaryKey"`
	Number      int     `gorm:"primaryKey;autoIncrement:false"`
	World       string  `gorm:"not null"` // world folder, e.g. "06-story-space"
	File        string  `gorm:"not null"` // path in the content, e.g. courses/x/worlds/06-a/levels/37-b.json
	Builtin     bool    `gorm:"not null;default:false"`
	Doc         string  `gorm:"type:text;not null"`
	LiveDoc     *string `gorm:"type:text"`
	CreatedBy   string  `gorm:"not null;default:''"`
	UpdatedBy   string  `gorm:"not null;default:''"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
	PublishedAt *time.Time
}

// ContentWorld is a world added in the admin panel. It is served once one
// of its levels is published.
type ContentWorld struct {
	CourseID  string `gorm:"type:varchar(64);primaryKey"`
	Folder    string `gorm:"primaryKey"` // e.g. "07-ocean-deep"
	Order     int    `gorm:"not null"`
	Doc       string `gorm:"type:text;not null"` // world.json
	CreatedBy string `gorm:"not null;default:''"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

// AdminSetting is a small piece of panel configuration (alert rules, the
// content revision), as JSON.
type AdminSetting struct {
	Key       string `gorm:"primaryKey"`
	Value     JSON   `gorm:"type:jsonb;not null"`
	UpdatedAt time.Time
}

// PlaySubscription is one Google Play purchase of Likho Plus (one purchase
// token), as Google last reported it (service.BillingService). The
// family's Plus (Parent.PlusUntil) is extended to its expiry; a token
// belongs to one account only.
type PlaySubscription struct {
	PurchaseToken string    `gorm:"primaryKey"`
	ParentID      string    `gorm:"type:uuid;not null;index"`
	ProductID     string    `gorm:"not null"`
	BasePlanID    string    `gorm:"not null;default:''"` // monthly | yearly
	OfferID       string    `gorm:"not null;default:''"` // e.g. the free trial
	State         string    `gorm:"type:varchar(48);not null"`
	ExpiresAt     time.Time `gorm:"not null"`
	AutoRenewing  bool      `gorm:"not null;default:false"`
	Acknowledged  bool      `gorm:"not null;default:false"`
	OrderID       string    `gorm:"not null;default:''"`
	LinkedToken   string    `gorm:"not null;default:''"`    // the purchase this one replaced
	Test          bool      `gorm:"not null;default:false"` // a license tester's purchase
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

// Google Play closed test: before launch, a new Play account must have
// testers opted in for 14 days in a row. The panel tracks them by the
// Likho account each one uses (never by a device id): a tester may sign in
// with another email than the one added in Play Console, so the team links
// accounts to testers (an email match links on its own).

// ClosedTester is a person in the closed test.
type ClosedTester struct {
	ID        string              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Name      string              `gorm:"not null;check:char_length(name) BETWEEN 1 AND 80" json:"name"`
	Email     string              `gorm:"not null;default:''" json:"email"`                  // as added in Play Console
	Phone     string              `gorm:"type:varchar(16);not null;default:''" json:"phone"` // WhatsApp: digits with the country code
	Note      string              `gorm:"not null;default:''" json:"note"`
	CreatedAt time.Time           `json:"createdAt"`
	Accounts  []ClosedTestAccount `gorm:"foreignKey:TesterID;constraint:OnDelete:CASCADE" json:"-"`
}

// ClosedTestAccount says whose Likho account this is: a tester's, or
// nobody's (TesterID nil: e.g. the team's own phone).
type ClosedTestAccount struct {
	ParentID string    `gorm:"type:uuid;primaryKey"`
	TesterID *string   `gorm:"type:uuid;index"`
	Auto     bool      `gorm:"not null;default:false"` // linked by its email
	LinkedAt time.Time `gorm:"not null;default:now()"`
}

// ClosedTestDay is one row per account per day it used the app while the
// closed test is set up. Days are in the test's time zone (active_days are
// UTC days).
type ClosedTestDay struct {
	ParentID string    `gorm:"type:uuid;primaryKey"`
	Day      time.Time `gorm:"type:date;primaryKey"`
}

// Tables, in the order GORM creates them.
var Tables = []any{
	&Parent{}, &Child{}, &LevelProgress{}, &ChildItem{}, &PlayDay{}, &Session{},
	&ActivityEvent{}, &ActiveDay{}, &AdminUser{}, &AdminSession{}, &AdminAlert{}, &AuditEntry{},
	&ContentLevel{}, &ContentWorld{}, &AdminSetting{}, &PlaySubscription{},
	&ClosedTester{}, &ClosedTestAccount{}, &ClosedTestDay{},
}

// Account, Settings and Subscription are the parent as the API shows it.

func (p Parent) Account() Account {
	return Account{ID: p.ID, Email: p.Email, Name: p.Name, PictureURL: p.PictureURL, Tester: p.Tester}
}

func (p Parent) Settings() Settings {
	return Settings{
		SessionMinutes: p.SessionMinutes, Music: p.Music, Sfx: p.Sfx, Haptics: p.Haptics,
		LeftHanded: p.LeftHanded, ReduceMotion: p.ReduceMotion,
	}
}

func (p Parent) Subscription(now time.Time) Subscription {
	return Subscription{Active: p.PlusActive(now), PlusUntil: p.PlusUntil, TrialUsed: p.TrialUsed, StoreAccountID: domain.StoreAccountID(p.ID)}
}
