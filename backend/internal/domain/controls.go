package domain

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode/utf8"
)

// App controls: what the team switches on and off in the admin panel
// (App controls page) and the app follows: features, story episodes, the
// Mascot Room's items, game types, Pencil's colours, Likho Plus (free
// levels, trial, plans) and the app's state (update, maintenance, a
// message to parents). The server checks what it can (levels, items, the
// trial); the app hides the rest.

// Who a switch is on for.
const (
	ModeOff    = "off"    // nobody
	ModeOn     = "on"     // everyone
	ModePlus   = "plus"   // families with Likho Plus
	ModeChosen = "chosen" // only the families it is turned on for (family page)
)

// Feature is one switch on the App controls page.
type Feature struct {
	ID      string
	Default string
	Modes   []string // the modes it can have
}

var (
	allModes    = []string{ModeOff, ModeOn, ModePlus, ModeChosen}
	onOffModes  = []string{ModeOff, ModeOn}
	onOffChosen = []string{ModeOff, ModeOn, ModeChosen}
)

// Features, in the order the panel shows them.
var Features = []Feature{
	{"stories", ModeOff, allModes},
	{"games", ModeOn, allModes},
	{"room", ModeOn, allModes},
	{"stickers", ModeOn, allModes},
	{"certificate", ModeOn, onOffModes},
	{"placement", ModeOn, onOffModes},
	{"guest", ModeOn, onOffModes},
	{"sfx", ModeOn, onOffChosen},
	{"voice", ModeOn, onOffChosen},
	{"haptics", ModeOn, onOffChosen},
}

// FeatureByID returns the feature with [id].
func FeatureByID(id string) (Feature, bool) {
	for _, f := range Features {
		if f.ID == id {
			return f, true
		}
	}
	return Feature{}, false
}

// Episode is a story the app has (lib/data/story.dart storyEpisodes).
type Episode struct{ ID, Letter, Title string }

var StoryEpisodes = []Episode{{"a", "A", "Dada's Apple Garden"}}

// PlayGame is a game on the app's Games screen (lib/data/games.dart GameIds).
type PlayGame struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

var PlayGames = []PlayGame{
	{"monsters", "Monster Defense"},
	{"runner", "Spell Runner"},
	{"smash", "Monster Smash"},
	{"slice", "Letter Slice"},
}

func episodeIDs() []string {
	out := []string{}
	for _, e := range StoryEpisodes {
		out = append(out, e.ID)
	}
	return out
}

func playGameIDs() []string {
	out := []string{}
	for _, g := range PlayGames {
		out = append(out, g.ID)
	}
	return out
}

// GameTypes are the round types the team can switch off. Writing is the
// heart of every level and always stays.
var GameTypes = []string{"pick", "order", "sounds", "beats", "connect", "hunt", "fix", "sort", "match", "pop", "truth"}

// ValidOverrideKey: a family's own switch is a feature id, "story.<id>"
// or "game.<id>".
func ValidOverrideKey(k string) bool {
	if _, ok := FeatureByID(k); ok {
		return true
	}
	if id, ok := strings.CutPrefix(k, "story."); ok {
		return slices.Contains(episodeIDs(), id)
	}
	if id, ok := strings.CutPrefix(k, "game."); ok {
		return slices.Contains(playGameIDs(), id)
	}
	return false
}

// Controls is what the panel saves.
type Controls struct {
	Features     map[string]string `json:"features"`
	Stories      StoryControls     `json:"stories"`
	Room         RoomControls      `json:"room"`
	Games        map[string]bool   `json:"games"`
	PencilColors []string          `json:"pencilColors"`
	Billing      BillingControls   `json:"billing"`
	App          AppStatus         `json:"app"`
	TabBar       TabBarControls    `json:"tabBar"`
	GameList     GameListControls  `json:"gameList"`
}

type StoryControls struct {
	ComingSoon bool              `json:"comingSoon"` // the letters still to come
	Episodes   map[string]string `json:"episodes"`   // episode id -> mode
	Order      []string          `json:"order"`      // episode ids, the first at the top
	New        []string          `json:"new"`        // episodes tagged NEW (until the child has played them)
}

// GameListControls: the games on the Games screen, each on for everyone,
// Plus families, chosen families or nobody, in the team's order, some
// tagged NEW (until the child has played them).
type GameListControls struct {
	Order []string          `json:"order"`
	Modes map[string]string `json:"modes"`
	New   []string          `json:"new"`
}

type RoomControls struct {
	Items map[string]ItemControl `json:"items"`
}

type ItemControl struct {
	Hidden bool `json:"hidden"` // not in the shop, and not shown on Pencil or in the room
	Price  int  `json:"price"`  // stars
}

type BillingControls struct {
	// Enabled false: no Likho Plus at all, every level is free.
	Enabled     bool `json:"enabled"`
	FreeLevels  int  `json:"freeLevels"`  // levels 1..FreeLevels need no Plus
	GuestLevels int  `json:"guestLevels"` // levels a guest ("Try it first") can play
	// TrialLevels: during a free trial only levels up to this one are open
	// (0 = every level).
	TrialLevels int  `json:"trialLevels"`
	ServerTrial bool `json:"serverTrial"` // the free trial without a store (no Google Play)
	TrialDays   int  `json:"trialDays"`

	Monthly   bool     `json:"monthly"`
	Yearly    bool     `json:"yearly"`
	BestValue string   `json:"bestValue"` // "monthly" | "yearly" | ""
	Benefits  []string `json:"benefits"`  // the paywall's list

	// FreeForAllUntil: every level open for everyone until the end of this
	// day (YYYY-MM-DD, "" = no promotion).
	FreeForAllUntil string `json:"freeForAllUntil"`
}

type AppStatus struct {
	MinVersion    string `json:"minVersion"` // e.g. "0.1.0+7": older apps must update ("" = any)
	Maintenance   Notice `json:"maintenance"`
	ParentMessage Notice `json:"parentMessage"`
}

type Notice struct {
	On    bool   `json:"on"`
	Title string `json:"title"`
	Text  string `json:"text"`
}

// TabBarControls is the app's bottom bar (Map, Stories, Games, Parents):
// its look, how it moves, and each tab in the order it shows.
type TabBarControls struct {
	Style     string       `json:"style"`     // TabStyles
	Animation string       `json:"animation"` // TabAnimations: how a tab answers a tap
	Speed     string       `json:"speed"`     // TabSpeeds
	Wiggle    bool         `json:"wiggle"`    // a NEW tab hops now and then
	Surface   string       `json:"surface"`   // TabSurfaces
	BarColor  string       `json:"barColor"`  // #RRGGBB, for the "colour" surface
	Floating  bool         `json:"floating"`  // a pill above the bottom edge (false: on the edge)
	Roundness int          `json:"roundness"` // corner radius, 0 to 36
	Labels    bool         `json:"labels"`    // names under the pictures
	Start     string       `json:"start"`     // the tab the app opens on
	Tabs      []TabControl `json:"tabs"`
}

// TabControl is one tab of the bottom bar.
type TabControl struct {
	ID    string `json:"id"` // TabIDs
	Shown bool   `json:"shown"`
	Label string `json:"label"`
	Color string `json:"color"` // #RRGGBB
	Badge bool   `json:"badge"` // "NEW" until the child has opened it
}

// The bottom bar's choices. Stories and Games also follow their feature
// switches; Map always shows; Parents opens the parent gate.
var (
	TabIDs        = []string{"map", "stories", "games", "parents"}
	TabStyles     = []string{"candy", "jelly", "island"}
	TabAnimations = []string{"bounce", "slide", "pop", "none"}
	TabSpeeds     = []string{"slow", "normal", "fast"}
	TabSurfaces   = []string{"white", "glass", "colour"}
)

// DefaultTabBar is the bar before the team changes it.
func DefaultTabBar() TabBarControls {
	return TabBarControls{
		Style: "candy", Animation: "bounce", Speed: "normal", Wiggle: true,
		Surface: "white", BarColor: "#7C5CFF", Floating: true, Roundness: 28, Labels: true, Start: "map",
		Tabs: []TabControl{
			{ID: "map", Shown: true, Label: "Map", Color: "#FFC83D"},
			{ID: "stories", Shown: true, Label: "Stories", Color: "#4D9DE0", Badge: true},
			{ID: "games", Shown: true, Label: "Games", Color: "#7C5CFF", Badge: true},
			{ID: "parents", Shown: true, Label: "Parents", Color: "#3BB273"},
		},
	}
}

// DefaultBenefits is the paywall's list.
var DefaultBenefits = []string{
	"Every world and every level",
	"The full course, from phonics to stories",
	"Weekly progress for parents",
	"Up to 4 child profiles, no ads",
}

// DefaultControls is what the app does before anything is saved: as it
// always did, with stories still off. [freeLevels] comes from the content.
func DefaultControls(freeLevels int) Controls {
	c := Controls{
		Features: map[string]string{},
		Stories:  StoryControls{ComingSoon: true, Episodes: map[string]string{}},
		Room:     RoomControls{Items: map[string]ItemControl{}},
		Games:    map[string]bool{},
		Billing: BillingControls{
			Enabled: true, FreeLevels: freeLevels, GuestLevels: 1, ServerTrial: true, TrialDays: TrialDays,
			Monthly: true, Yearly: true, BestValue: "yearly", Benefits: slices.Clone(DefaultBenefits),
		},
		App: AppStatus{
			Maintenance: Notice{Title: "We'll be right back", Text: "Likho is getting a little update. Please try again in a few minutes."},
		},
	}
	for _, f := range Features {
		c.Features[f.ID] = f.Default
	}
	for _, e := range StoryEpisodes {
		c.Stories.Episodes[e.ID] = ModeOn
	}
	for id, it := range Items {
		c.Room.Items[id] = ItemControl{Price: it.Price}
	}
	for _, g := range GameTypes {
		c.Games[g] = true
	}
	c.PencilColors = slices.Clone(PencilColorOrder)
	c.TabBar = DefaultTabBar()
	c.Stories.Order, c.Stories.New = episodeIDs(), []string{}
	c.GameList = GameListControls{Order: playGameIDs(), Modes: map[string]string{}, New: []string{"smash", "slice"}}
	for _, id := range playGameIDs() {
		c.GameList.Modes[id] = ModeOn
	}
	return c
}

// tidyOrder keeps the known [ids] of [order] once each, in its order, and
// puts the ones it lacks (added since) at the end.
func tidyOrder(order, ids []string) []string {
	out := []string{}
	for _, id := range order {
		if slices.Contains(ids, id) && !slices.Contains(out, id) {
			out = append(out, id)
		}
	}
	for _, id := range ids {
		if !slices.Contains(out, id) {
			out = append(out, id)
		}
	}
	return out
}

// tidySet keeps the known [ids] of [list] once each.
func tidySet(list, ids []string) []string {
	out := []string{}
	for _, id := range list {
		if slices.Contains(ids, id) && !slices.Contains(out, id) {
			out = append(out, id)
		}
	}
	return out
}

// PencilColorOrder is the order the app shows Pencil's colours in.
var PencilColorOrder = []string{"#FFC83D", "#4D9DE0", "#3BB273", "#FF8A5B", "#B79CED", "#FF9EB5"}

// Fill fills what an older save lacks (a feature added since) with the
// defaults, so the app always gets every switch.
func (c Controls) Fill(def Controls) Controls {
	if c.Features == nil {
		c.Features = map[string]string{}
	}
	for k, v := range def.Features {
		if _, ok := c.Features[k]; !ok {
			c.Features[k] = v
		}
	}
	if c.Stories.Episodes == nil {
		c.Stories.Episodes = map[string]string{}
	}
	for k, v := range def.Stories.Episodes {
		if _, ok := c.Stories.Episodes[k]; !ok {
			c.Stories.Episodes[k] = v
		}
	}
	if c.Room.Items == nil {
		c.Room.Items = map[string]ItemControl{}
	}
	for k, v := range def.Room.Items {
		if _, ok := c.Room.Items[k]; !ok {
			c.Room.Items[k] = v
		}
	}
	if c.Games == nil {
		c.Games = map[string]bool{}
	}
	for k, v := range def.Games {
		if _, ok := c.Games[k]; !ok {
			c.Games[k] = v
		}
	}
	if c.PencilColors == nil {
		c.PencilColors = def.PencilColors
	}
	if c.Billing.Benefits == nil {
		c.Billing.Benefits = def.Billing.Benefits
	}
	if c.TabBar.Style == "" { // saved before the bottom bar
		c.TabBar = def.TabBar
	}
	if c.Stories.Order == nil { // saved before the order
		c.Stories.Order = def.Stories.Order
	}
	c.Stories.Order = tidyOrder(c.Stories.Order, episodeIDs())
	if c.Stories.New == nil {
		c.Stories.New = []string{}
	}
	if c.GameList.Order == nil { // saved before the game list
		c.GameList = def.GameList
	}
	if c.GameList.Modes == nil {
		c.GameList.Modes = map[string]string{}
	}
	for k, v := range def.GameList.Modes {
		if _, ok := c.GameList.Modes[k]; !ok {
			c.GameList.Modes[k] = v
		}
	}
	c.GameList.Order = tidyOrder(c.GameList.Order, playGameIDs())
	if c.GameList.New == nil {
		c.GameList.New = []string{}
	}
	for _, t := range def.TabBar.Tabs { // a tab added since: at the end
		if !slices.ContainsFunc(c.TabBar.Tabs, func(x TabControl) bool { return x.ID == t.ID }) {
			c.TabBar.Tabs = append(c.TabBar.Tabs, t)
		}
	}
	return c
}

var (
	versionRe = regexp.MustCompile(`^\d{1,4}\.\d{1,4}\.\d{1,4}(\+\d{1,6})?$`)
	dateRe    = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	hexRe     = regexp.MustCompile(`^#[0-9A-F]{6}$`)
)

// Validate checks a save from the panel against the course's [lastLevel].
// It also tidies it (trims texts, drops unknown keys).
func (c *Controls) Validate(lastLevel int) error {
	for id, m := range c.Features {
		f, ok := FeatureByID(id)
		if !ok {
			delete(c.Features, id)
			continue
		}
		if !slices.Contains(f.Modes, m) {
			return Invalid(fmt.Sprintf("feature %s cannot be %q", id, m))
		}
	}
	for id, m := range c.Stories.Episodes {
		if !slices.ContainsFunc(StoryEpisodes, func(e Episode) bool { return e.ID == id }) {
			delete(c.Stories.Episodes, id)
			continue
		}
		if !slices.Contains(allModes, m) {
			return Invalid(fmt.Sprintf("story %s cannot be %q", id, m))
		}
	}
	c.Stories.Order = tidyOrder(c.Stories.Order, episodeIDs())
	c.Stories.New = tidySet(c.Stories.New, episodeIDs())
	if c.GameList.Modes == nil {
		c.GameList.Modes = map[string]string{}
	}
	for id, m := range c.GameList.Modes {
		if !slices.Contains(playGameIDs(), id) {
			delete(c.GameList.Modes, id)
			continue
		}
		if !slices.Contains(allModes, m) {
			return Invalid(fmt.Sprintf("game %s cannot be %q", id, m))
		}
	}
	for _, id := range playGameIDs() {
		if _, ok := c.GameList.Modes[id]; !ok {
			c.GameList.Modes[id] = ModeOn
		}
	}
	c.GameList.Order = tidyOrder(c.GameList.Order, playGameIDs())
	c.GameList.New = tidySet(c.GameList.New, playGameIDs())
	for id, it := range c.Room.Items {
		if _, ok := Items[id]; !ok {
			delete(c.Room.Items, id)
			continue
		}
		if it.Price < 1 || it.Price > 999 {
			return Invalid(fmt.Sprintf("the price of %s must be 1 to 999 stars", id))
		}
	}
	for g := range c.Games {
		if !slices.Contains(GameTypes, g) {
			delete(c.Games, g)
		}
	}
	colors := []string{}
	for _, col := range c.PencilColors {
		col = strings.ToUpper(col)
		if !PencilColors[col] {
			return Invalid("unknown Pencil colour " + col)
		}
		if !slices.Contains(colors, col) {
			colors = append(colors, col)
		}
	}
	if len(colors) == 0 {
		return Invalid("keep at least one Pencil colour")
	}
	c.PencilColors = colors

	b := &c.Billing
	switch {
	case b.FreeLevels < 0 || b.FreeLevels > lastLevel:
		return Invalid(fmt.Sprintf("free levels must be 0 to %d", lastLevel))
	case b.GuestLevels < 0 || b.GuestLevels > lastLevel:
		return Invalid(fmt.Sprintf("guest levels must be 0 to %d", lastLevel))
	case b.Enabled && b.GuestLevels > b.FreeLevels:
		return Invalid("guests can only play free levels")
	case b.TrialLevels < 0 || b.TrialLevels > lastLevel:
		return Invalid(fmt.Sprintf("trial levels must be 0 (all) to %d", lastLevel))
	case b.TrialLevels != 0 && b.TrialLevels <= b.FreeLevels:
		return Invalid("the trial must open more levels than the free ones")
	case b.TrialDays < 1 || b.TrialDays > 90:
		return Invalid("trial days must be 1 to 90")
	case !b.Monthly && !b.Yearly:
		return Invalid("offer at least one plan")
	case b.BestValue != "" && b.BestValue != "monthly" && b.BestValue != "yearly":
		return Invalid("best value must be monthly or yearly")
	case b.FreeForAllUntil != "" && !validDate(b.FreeForAllUntil):
		return Invalid("free for everyone until: a date like 2026-12-31")
	}
	if (b.BestValue == "monthly" && !b.Monthly) || (b.BestValue == "yearly" && !b.Yearly) {
		b.BestValue = ""
	}
	benefits := []string{}
	for _, s := range b.Benefits {
		if s = strings.TrimSpace(s); s == "" {
			continue
		}
		if utf8.RuneCountInString(s) > 60 {
			return Invalid("each Likho Plus line can be up to 60 characters")
		}
		benefits = append(benefits, s)
	}
	if len(benefits) > 5 {
		return Invalid("up to 5 Likho Plus lines")
	}
	b.Benefits = benefits

	a := &c.App
	a.MinVersion = strings.TrimSpace(a.MinVersion)
	if a.MinVersion != "" && !versionRe.MatchString(a.MinVersion) {
		return Invalid("minimum version must look like 0.1.0+7")
	}
	for _, n := range []*Notice{&a.Maintenance, &a.ParentMessage} {
		n.Title, n.Text = strings.TrimSpace(n.Title), strings.TrimSpace(n.Text)
		if utf8.RuneCountInString(n.Title) > 60 || utf8.RuneCountInString(n.Text) > 300 {
			return Invalid("messages: a title up to 60 and a text up to 300 characters")
		}
	}
	if a.Maintenance.On && a.Maintenance.Text == "" {
		return Invalid("write what the maintenance screen says")
	}
	if a.ParentMessage.On && a.ParentMessage.Text == "" {
		return Invalid("write the message to parents")
	}
	return c.TabBar.validate()
}

// validate checks and tidies the bottom bar: known tabs once each (a
// missing one goes at the end, hidden), Map always shown, labels and
// colours that the app can draw.
func (t *TabBarControls) validate() error {
	for _, v := range []struct {
		name, value string
		allowed     []string
	}{
		{"style", t.Style, TabStyles}, {"animation", t.Animation, TabAnimations},
		{"speed", t.Speed, TabSpeeds}, {"surface", t.Surface, TabSurfaces},
	} {
		if !slices.Contains(v.allowed, v.value) {
			return Invalid(fmt.Sprintf("bottom bar %s cannot be %q", v.name, v.value))
		}
	}
	if t.Roundness < 0 || t.Roundness > 36 {
		return Invalid("bottom bar roundness must be 0 to 36")
	}
	if t.BarColor = strings.ToUpper(t.BarColor); !hexRe.MatchString(t.BarColor) {
		return Invalid("bottom bar colour must look like #7C5CFF")
	}
	def := DefaultTabBar()
	tabs := []TabControl{}
	for _, tab := range t.Tabs {
		if !slices.Contains(TabIDs, tab.ID) {
			continue
		}
		if slices.ContainsFunc(tabs, func(x TabControl) bool { return x.ID == tab.ID }) {
			return Invalid("each tab can be in the bottom bar once")
		}
		if tab.Label = strings.TrimSpace(tab.Label); tab.Label == "" {
			return Invalid("give the " + tab.ID + " tab a name")
		}
		if utf8.RuneCountInString(tab.Label) > 12 {
			return Invalid("tab names can be up to 12 characters")
		}
		if tab.Color = strings.ToUpper(tab.Color); !hexRe.MatchString(tab.Color) {
			return Invalid("the " + tab.ID + " tab's colour must look like #FFC83D")
		}
		if tab.ID == "map" {
			tab.Shown = true // the course is the app: Map never goes
		}
		tabs = append(tabs, tab)
	}
	for _, d := range def.Tabs {
		if !slices.ContainsFunc(tabs, func(x TabControl) bool { return x.ID == d.ID }) {
			d.Shown = d.ID == "map"
			tabs = append(tabs, d)
		}
	}
	t.Tabs = tabs
	if t.Start == "parents" || !slices.ContainsFunc(tabs, func(x TabControl) bool { return x.ID == t.Start && x.Shown }) {
		return Invalid("the app can open on Map, or on Stories or Games when they are shown")
	}
	return nil
}

func validDate(s string) bool {
	if !dateRe.MatchString(s) {
		return false
	}
	_, err := time.Parse("2006-01-02", s)
	return err == nil
}

// FreeForAll says whether the promotion runs at [now] (until the end of
// its day, UTC).
func (b BillingControls) FreeForAll(now time.Time) bool {
	if b.FreeForAllUntil == "" {
		return false
	}
	day, err := time.Parse("2006-01-02", b.FreeForAllUntil)
	return err == nil && now.Before(day.AddDate(0, 0, 1))
}

// PlusFree: nobody needs Likho Plus right now (billing off, or the
// promotion).
func (b BillingControls) PlusFree(now time.Time) bool { return !b.Enabled || b.FreeForAll(now) }

// NeedsPlus says whether [level] needs Likho Plus at [now].
func (b BillingControls) NeedsPlus(level int, now time.Time) bool {
	return !b.PlusFree(now) && level > b.FreeLevels
}

// TrialBlocks says whether a family in its free trial cannot play [level].
func (b BillingControls) TrialBlocks(level int, now time.Time) bool {
	return b.NeedsPlus(level, now) && b.TrialLevels > 0 && level > b.TrialLevels
}

// Item is the shop item with its price from the controls; false when it
// is unknown or hidden.
func (c Controls) Item(id string) (Item, bool) {
	it, ok := Items[id]
	if !ok {
		return Item{}, false
	}
	if ctl, ok := c.Room.Items[id]; ok {
		if ctl.Hidden {
			return Item{}, false
		}
		if ctl.Price > 0 {
			it.Price = ctl.Price
		}
	}
	return it, true
}

// Resolve is the mode a family gets for a switch: [mode] as saved, with
// the family's own switch ([override], nil = none) and whether Likho Plus
// is free for everyone. The app gets off, on or plus (on when the family
// has Plus).
func Resolve(mode string, override *bool, plusFree bool) string {
	if override != nil {
		if *override {
			return ModeOn
		}
		return ModeOff
	}
	switch mode {
	case ModeChosen:
		return ModeOff
	case ModePlus:
		if plusFree {
			return ModeOn
		}
	}
	return mode
}

// NoticeID changes whenever the message does (the app remembers which
// message a parent closed).
func (n Notice) ID() string {
	h := sha1.Sum([]byte(n.Title + "\x00" + n.Text))
	return hex.EncodeToString(h[:4])
}
