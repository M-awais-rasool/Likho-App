package models

import "time"

// Database tables (GORM models). GORM creates and updates the tables from
// these structs at start-up (database.Migrate); the tags carry the
// constraints and indexes.

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
	ID        string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	ParentID  string    `gorm:"type:uuid;not null;index:idx_children_parent,priority:1"`
	Name      string    `gorm:"not null;check:char_length(name) BETWEEN 1 AND 14"`
	Age       int       `gorm:"type:smallint;not null;check:age BETWEEN 5 AND 8"`
	Color     string    `gorm:"not null"` // Pencil colour, e.g. "#FFC83D"
	Stars     int       `gorm:"not null;default:0;check:stars >= 0"`
	Wearing   *string   // shop item id Pencil wears
	CreatedAt time.Time `gorm:"index:idx_children_parent,priority:2"`
	UpdatedAt time.Time

	LevelResults []LevelResult `gorm:"constraint:OnDelete:CASCADE"`
	Items        []ChildItem   `gorm:"constraint:OnDelete:CASCADE"`
	PlayDays     []PlayDay     `gorm:"constraint:OnDelete:CASCADE"`
}

// LevelResult is the best result of a child on a level (1..36).
type LevelResult struct {
	ChildID   string    `gorm:"type:uuid;primaryKey"`
	Level     int       `gorm:"type:smallint;primaryKey;autoIncrement:false;check:level BETWEEN 1 AND 36"`
	BestStars int       `gorm:"type:smallint;not null;check:best_stars BETWEEN 1 AND 3"`
	Plays     int       `gorm:"not null;default:1"`
	FirstAt   time.Time `gorm:"not null;default:now()"`
	LastAt    time.Time `gorm:"not null;default:now()"`
}

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

// CourseVersion is the course content (the app's course.json); the newest
// row is served.
type CourseVersion struct {
	ID        uint      `gorm:"primaryKey"`
	Sha256    string    `gorm:"uniqueIndex;not null"`
	Body      string    `gorm:"type:jsonb;not null"`
	CreatedAt time.Time `gorm:"index"`
}

// Tables, in the order GORM creates them.
var Tables = []any{&Parent{}, &Child{}, &LevelResult{}, &ChildItem{}, &PlayDay{}, &Session{}, &CourseVersion{}}
