package model

import "time"

// What the API sends and receives (see docs/openapi.yaml). JSON names match
// the Flutter app (camelCase).

// Account is the signed-in parent.
type Account struct {
	ID         string `json:"id"`
	Email      string `json:"email"`
	Name       string `json:"name"`
	PictureURL string `json:"pictureUrl"`
	Tester     bool   `json:"tester"` // test account: every level is open
}

type Settings struct {
	SessionMinutes int  `json:"sessionMinutes"` // 5, 10 or 15
	Music          bool `json:"music"`
	Sfx            bool `json:"sfx"`
	Haptics        bool `json:"haptics"`
	LeftHanded     bool `json:"leftHanded"`
	ReduceMotion   bool `json:"reduceMotion"`
}

// SettingsPatch changes only the fields that are sent.
type SettingsPatch struct {
	SessionMinutes *int  `json:"sessionMinutes"`
	Music          *bool `json:"music"`
	Sfx            *bool `json:"sfx"`
	Haptics        *bool `json:"haptics"`
	LeftHanded     *bool `json:"leftHanded"`
	ReduceMotion   *bool `json:"reduceMotion"`
}

type Subscription struct {
	Active    bool       `json:"active"`
	PlusUntil *time.Time `json:"plusUntil"`
	TrialUsed bool       `json:"trialUsed"`

	// A Google Play subscription behind it ("" = none: a trial or a
	// grant): its base plan (monthly | yearly) and whether it renews.
	Store        string `json:"store,omitempty"` // "google_play"
	Plan         string `json:"plan,omitempty"`
	AutoRenewing bool   `json:"autoRenewing"`

	// StoreAccountID goes with a Google Play purchase
	// (obfuscatedAccountId), so the server knows whose it is.
	StoreAccountID string `json:"storeAccountId"`
}

// ChildView is a child with everything the app shows for it (map, room,
// profile, sticker book, parent dashboard).
type ChildView struct {
	ID              string   `json:"id"`
	Name            string   `json:"name"`
	Age             int      `json:"age"`
	Color           string   `json:"color"`
	Stars           int      `json:"stars"` // shared by all courses, spent in the room
	Wearing         *string  `json:"wearing"`
	Owned           []string `json:"owned"`
	Room            []string `json:"room"`
	DaysPlayed      int      `json:"daysPlayed"`
	MinutesThisWeek int      `json:"minutesThisWeek"`

	// Progress per course id: {"english-handwriting": {"levelStars": {"1": 3}}}.
	Progress map[string]CourseProgress `json:"progress"`
}

// CourseProgress is a child's progress in one course.
type CourseProgress struct {
	LevelStars map[string]int `json:"levelStars"` // level number -> best stars
}

type ChildInput struct {
	Name  string `json:"name"`
	Age   int    `json:"age"`
	Color string `json:"color"`
}

// ChildPatch changes only the fields that are sent.
type ChildPatch struct {
	Name  *string `json:"name"`
	Age   *int    `json:"age"`
	Color *string `json:"color"`
}

// Me is everything the app needs after sign-in, in one response.
type Me struct {
	Account      Account      `json:"account"`
	Settings     Settings     `json:"settings"`
	Subscription Subscription `json:"subscription"`
	Children     []ChildView  `json:"children"`
}

// ResultInput is a finished level (the course and child are in the path).
type ResultInput struct {
	Level   int `json:"level"`
	Stars   int `json:"stars"`
	Seconds int `json:"seconds"` // time spent in the level (optional)
}

// Outcome of a finished level (the Level Complete screen).
type Outcome struct {
	CourseID   string `json:"courseId"`
	Level      int    `json:"level"`
	Stars      int    `json:"stars"`
	BestStars  int    `json:"bestStars"`
	Gain       int    `json:"gain"` // stars added to the child's total
	FirstTime  bool   `json:"firstTime"`
	TotalStars int    `json:"totalStars"`
}

// RoomState after a Mascot Room tap.
type RoomState struct {
	Action  string   `json:"action"` // bought | worn | taken_off | placed | removed
	Stars   int      `json:"stars"`
	Wearing *string  `json:"wearing"`
	Owned   []string `json:"owned"`
	Room    []string `json:"room"`
}

type Tokens struct {
	AccessToken  string `json:"accessToken"`
	ExpiresIn    int    `json:"expiresIn"` // seconds
	RefreshToken string `json:"refreshToken"`
}

// SignIn is the answer to "Continue with Google": tokens + the whole account.
type SignIn struct {
	Tokens
	IsNewAccount bool `json:"isNewAccount"`
	Me           Me   `json:"me"`
}

// GoogleUser is what a verified Google ID token says about the user.
type GoogleUser struct {
	Sub, Email, Name, Picture string
}

// CourseSummary describes a course in the catalog (GET /v1/courses).
type CourseSummary struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Locale      string `json:"locale"`
	Ages        *Ages  `json:"ages"`
	Worlds      int    `json:"worlds"`
	Levels      int    `json:"levels"`
	Version     string `json:"version"` // changes whenever the content does (= ETag)
	UpdatedAt   string `json:"updatedAt"`
}

type Ages struct {
	Min int `json:"min"`
	Max int `json:"max"`
}

// ClientInfo is what a request says about the device (for the admin
// panel): set by the app in X-Likho-* headers, plus the client IP and the
// CDN's country header. The IP is only used to look up the country.
type ClientInfo struct {
	IP            string
	CountryHeader string
	Region        string // phone's region (language setting), e.g. "PK"
	Platform      string // ios | android | web
	AppVersion    string
}
