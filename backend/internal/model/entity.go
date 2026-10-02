// Package model holds the data shapes: entity.go = database tables (GORM),
// dto.go = the JSON the API sends and receives.
package model

import "time"

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

	CreatedAt   time.Time
	LastLoginAt time.Time `gorm:"not null;default:now()"`

	Children []Child   `gorm:"constraint:OnDelete:CASCADE"`
	Sessions []Session `gorm:"constraint:OnDelete:CASCADE"`
}

func (p Parent) PlusActive(now time.Time) bool { return p.PlusUntil != nil && p.PlusUntil.After(now) }

// Child is one of up to 4 profiles under a parent.
type Child struct {
	ID       string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	ParentID string `gorm:"type:uuid;not null;index:idx_children_parent,priority:1"`
	Name     string `gorm:"not null;check:char_length(name) BETWEEN 1 AND 14"`
	Age      *int   `gorm:"type:smallint;check:age BETWEEN 5 AND 8"` // asked before the class was; empty since

	// School class (domain.Grades) and the highest class open on the map:
	// the child's own, or a higher one a parent opened. Not checked by the
	// database, so a class can be added without a migration. Empty for a
	// child from before classes until start-up fills it in (FillGrades).
	Grade         string `gorm:"type:varchar(16);not null;default:''"`
	UnlockedGrade string `gorm:"type:varchar(16);not null;default:''"`
	// When a parent last picked or confirmed the class; nil = never (a
	// class guessed from the age), so the app asks.
	GradeConfirmedAt *time.Time

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

// Tables, in the order GORM creates them.
var Tables = []any{&Parent{}, &Child{}, &LevelProgress{}, &ChildItem{}, &PlayDay{}, &Session{}}

// Account, Settings and Subscription are the parent as the API shows it.

func (p Parent) Account() Account {
	return Account{ID: p.ID, Email: p.Email, Name: p.Name, PictureURL: p.PictureURL}
}

func (p Parent) Settings() Settings {
	return Settings{
		SessionMinutes: p.SessionMinutes, Music: p.Music, Sfx: p.Sfx, Haptics: p.Haptics,
		LeftHanded: p.LeftHanded, ReduceMotion: p.ReduceMotion,
	}
}

func (p Parent) Subscription(now time.Time) Subscription {
	return Subscription{Active: p.PlusActive(now), PlusUntil: p.PlusUntil, TrialUsed: p.TrialUsed}
}
