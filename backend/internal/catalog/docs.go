package catalog

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"

	"likho/backend/internal/model"
)

// The content files, field by field (content/schema/*.schema.json describe
// the same for editors). Unknown fields are rejected when reading.

type manifestDoc struct {
	Schema        string      `json:"$schema"`
	ID            string      `json:"id"`
	Title         string      `json:"title"`
	Description   string      `json:"description"`
	Locale        string      `json:"locale"`
	Ages          *model.Ages `json:"ages"`
	Status        string      `json:"status"`
	SchemaVersion int         `json:"schemaVersion"`
	UpdatedAt     string      `json:"updatedAt"`
}

func (m manifestDoc) check(file, folder string, p *problems) {
	switch {
	case m.ID != folder:
		p.add(file, "id %q must match the folder name %q", m.ID, folder)
	case !slugRe.MatchString(m.ID):
		p.add(file, "id %q must be lowercase words joined by dashes", m.ID)
	}
	if m.Title == "" {
		p.add(file, "title is required")
	}
	if m.Locale == "" {
		p.add(file, "locale is required")
	}
	if m.Status != "published" && m.Status != "draft" {
		p.add(file, `status must be "published" or "draft"`)
	}
	if m.SchemaVersion != SupportedSchema {
		p.add(file, "schemaVersion %d is not supported (this server reads %d)", m.SchemaVersion, SupportedSchema)
	}
	if !validTime(m.UpdatedAt) {
		p.add(file, "updatedAt must be a date-time like 2026-09-27T00:00:00Z")
	}
	if m.Ages != nil && m.Ages.Min > m.Ages.Max {
		p.add(file, "ages.min is above ages.max")
	}
}

type glyphsDoc struct {
	Schema string              `json:"$schema"`
	Glyphs map[string][]string `json:"glyphs"`
}

func (g glyphsDoc) check(file string, p *problems) {
	for k, strokes := range g.Glyphs {
		if k == "" || len(strokes) == 0 {
			p.add(file, "glyph %q needs at least one stroke", k)
		}
		for _, s := range strokes {
			if s == "" {
				p.add(file, "glyph %q has an empty stroke", k)
			}
		}
	}
}

type worldDoc struct {
	Schema  string `json:"$schema"`
	ID      string `json:"id"`
	Order   int    `json:"order"`
	Name    string `json:"name"`
	Skill   string `json:"skill"`
	Icon    string `json:"icon"`
	ThemeID string `json:"themeId"`
	Boss    *struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"boss"`
}

func (w worldDoc) check(file, folder string, p *problems) {
	if !slugRe.MatchString(w.ID) {
		p.add(file, "id %q must be lowercase words joined by dashes", w.ID)
	}
	if w.Order < 1 {
		p.add(file, "order must be 1 or more")
	} else if prefix := fmt.Sprintf("%02d-", w.Order); len(folder) < len(prefix) || folder[:len(prefix)] != prefix {
		p.add(file, "folder name must start with the world order (%s…)", prefix)
	}
	if w.Name == "" || w.Icon == "" || w.ThemeID == "" {
		p.add(file, "name, icon and themeId are required")
	}
	if w.Boss == nil || w.Boss.ID == "" || w.Boss.Name == "" {
		p.add(file, "boss {id, name} is required")
	}
}

type levelDoc struct {
	Schema               string           `json:"$schema"`
	ID                   string           `json:"id"`
	Number               *int             `json:"number"`
	Name                 string           `json:"name"`
	Skill                string           `json:"skill"`
	Icon                 string           `json:"icon"`
	IsBoss               *bool            `json:"isBoss"`
	RequiresSubscription *bool            `json:"requiresSubscription"`
	Intro                *introDoc        `json:"intro"`
	Presentation         *presentationDoc `json:"presentation"`
	Rounds               []roundDoc       `json:"rounds"`
}

type pictureDoc struct {
	Key   string  `json:"key"`
	Label string  `json:"label"`
	URL   *string `json:"url"`
}

type introDoc struct {
	Text    string      `json:"text"`
	Word    string      `json:"word"`
	Say     *string     `json:"say"`
	Audio   *string     `json:"audio"`
	Picture *pictureDoc `json:"picture"`
}

type presentationDoc struct {
	Shape  *string `json:"shape"`
	Slot   *string `json:"slot"`
	Layout *string `json:"layout"`
	Stage  *string `json:"stage"`
}

type roundDoc struct {
	ID     string `json:"id"`
	Type   string `json:"type"`
	Prompt *struct {
		Text  string  `json:"text"`
		Say   *string `json:"say"`
		Audio *string `json:"audio"`
	} `json:"prompt"`
	Card *struct {
		Text    *string     `json:"text"`
		Picture *pictureDoc `json:"picture"`
		Listen  bool        `json:"listen"`
	} `json:"card"`
	Pick  *pickDoc  `json:"pick"`
	Write *writeDoc `json:"write"`
	Order *struct {
		Tiles []string `json:"tiles"`
		Slot  *string  `json:"slot"`
	} `json:"order"`
	Speak *struct {
		Expected *string `json:"expected"`
	} `json:"speak"`
	Hunt *struct {
		Target string   `json:"target"`
		Grid   []string `json:"grid"`
	} `json:"hunt"`
	Fix *struct {
		Items []struct {
			Text  string  `json:"text"`
			Wrong *string `json:"wrong"`
			At    *int    `json:"at"`
		} `json:"items"`
	} `json:"fix"`
	Sort *struct {
		Bins  []sortThing `json:"bins"`
		Items []sortThing `json:"items"`
	} `json:"sort"`
	Match *struct {
		Pairs []struct {
			A *matchSide `json:"a"`
			B *matchSide `json:"b"`
		} `json:"pairs"`
	} `json:"match"`
	Pop *struct {
		Target string   `json:"target"`
		Others []string `json:"others"`
		Count  int      `json:"count"`
	} `json:"pop"`
	Truth *struct {
		Text    string      `json:"text"`
		Picture *pictureDoc `json:"picture"`
		Answer  *bool       `json:"answer"`
	} `json:"truth"`
}

type sortThing struct {
	Label   string      `json:"label"`
	Picture *pictureDoc `json:"picture"`
	Bin     *int        `json:"bin"`
}

type matchSide struct {
	Text    *string     `json:"text"`
	Picture *pictureDoc `json:"picture"`
}

type pickDoc struct {
	Options []struct {
		ID        string      `json:"id"`
		Label     string      `json:"label"`
		Picture   *pictureDoc `json:"picture"`
		Color     *string     `json:"color"`
		HideLabel bool        `json:"hideLabel"`
	} `json:"options"`
	Answer *struct {
		Kind  string  `json:"kind"`
		Value *string `json:"value"`
	} `json:"answer"`
	Shape      *string `json:"shape"`
	Layout     *string `json:"layout"`
	Count      *int    `json:"count"`
	ChoiceKey  *string `json:"choiceKey"`
	FixCapital bool    `json:"fixCapital"`
	Stage      *string `json:"stage"`
}

type writeDoc struct {
	Mode         string  `json:"mode"`
	Target       *string `json:"target"`
	Guide        *string `json:"guide"`
	Word         *string `json:"word"`
	MissingIndex *int    `json:"missingIndex"`
	Sentence     bool    `json:"sentence"`
	Story        bool    `json:"story"`
}

// checker checks levels and rounds, including what one file cannot know
// alone: ids unique in the course, guides that exist in glyphs.json.
type checker struct {
	glyphs   map[string][]string
	levelIDs map[string]string // id -> file
	roundIDs map[string]string
	p        *problems
}

func (c *checker) level(l *parsed[levelDoc]) {
	d, file := l.doc, l.file
	if !slugRe.MatchString(d.ID) {
		c.p.add(file, "id %q must be lowercase words joined by dashes", d.ID)
	} else if prev, dup := c.levelIDs[d.ID]; dup {
		c.p.add(file, "level id %q is also used by %s", d.ID, prev)
	}
	c.levelIDs[d.ID] = file
	switch {
	case d.Number == nil:
		c.p.add(file, "number is required")
	case d.Name == "" || d.Icon == "":
		c.p.add(file, "name and icon are required")
	case d.IsBoss == nil || d.RequiresSubscription == nil:
		c.p.add(file, "isBoss and requiresSubscription are required (true or false)")
	case d.Intro == nil || d.Presentation == nil:
		c.p.add(file, "intro and presentation are required")
	case len(d.Rounds) == 0:
		c.p.add(file, "a level needs at least one round")
	}
	if d.Intro != nil {
		c.speech(file+" intro", d.Intro.Say, d.Intro.Audio)
	}
	for i := range d.Rounds {
		c.round(file, i, &d.Rounds[i])
	}
}

var (
	// a recording in the media folder ("voice/line-….m4a") or a URL
	audioRe = regexp.MustCompile(`^([a-z0-9_-]+/)+[A-Za-z0-9_.-]+\.(m4a|wav|mp3)$|^https?://.+$`)
	// {shown|IPA}: what the device voice reads | what recordings say
	pronRe = regexp.MustCompile(`\{[^{}|]+\|[^{}|]+\}`)
)

// speech checks spoken words and their recording: `say` is not empty and
// its {shown|IPA} parts are complete, `audio` is an app asset or a URL.
func (c *checker) speech(at string, say, audio *string) {
	if say != nil {
		rest := pronRe.ReplaceAllString(*say, "")
		switch {
		case strings.TrimSpace(*say) == "":
			c.p.add(at, "say is empty (leave it out to say the text)")
		case strings.ContainsAny(rest, "{}|"):
			c.p.add(at, "say %q: a pronunciation is written {shown|IPA}", *say)
		}
	}
	if audio != nil && !audioRe.MatchString(*audio) {
		c.p.add(at, "audio %q must be a file in the media folder (voice/….m4a, .wav or .mp3) or an http(s) URL", *audio)
	}
}

func (c *checker) round(file string, i int, r *roundDoc) {
	at := fmt.Sprintf("%s rounds[%d]", file, i)
	if r.ID == "" {
		c.p.add(at, "id is required")
	} else if prev, dup := c.roundIDs[r.ID]; dup {
		c.p.add(at, "round id %q is also used in %s", r.ID, prev)
	}
	c.roundIDs[r.ID] = file
	if r.Prompt == nil || r.Prompt.Text == "" {
		c.p.add(at, "prompt.text is required")
	} else {
		c.speech(at+" prompt", r.Prompt.Say, r.Prompt.Audio)
	}
	if !roundTypes[r.Type] {
		c.p.add(at, "type %q is not one of pick, write, order, speak, hunt, fix, sort, match, pop, truth", r.Type)
		return
	}
	payloads := map[string]bool{
		"pick": r.Pick != nil, "write": r.Write != nil, "order": r.Order != nil, "speak": r.Speak != nil, "hunt": r.Hunt != nil,
		"fix": r.Fix != nil, "sort": r.Sort != nil, "match": r.Match != nil, "pop": r.Pop != nil, "truth": r.Truth != nil,
	}
	for name, present := range payloads {
		if name == r.Type && !present {
			c.p.add(at, "a %q round needs a %q object", r.Type, r.Type)
		}
		if name != r.Type && present {
			c.p.add(at, "a %q round cannot have a %q object", r.Type, name)
		}
	}
	switch {
	case r.Pick != nil:
		c.pick(at, r.Pick)
	case r.Write != nil:
		if !writeModes[r.Write.Mode] {
			c.p.add(at, "write.mode %q is not one of trace, dots, free, flash, missing, spell", r.Write.Mode)
		}
		if g := r.Write.Guide; g != nil {
			if _, ok := c.glyphs[*g]; !ok {
				c.p.add(at, "write.guide %q is not in glyphs.json", *g)
			}
		}
	case r.Order != nil:
		if len(r.Order.Tiles) < 2 {
			c.p.add(at, "order.tiles needs at least two tiles")
		}
		if s := r.Order.Slot; s != nil && !slots[*s] {
			c.p.add(at, "order.slot %q is not one of wagon, plank, stripe, panel", *s)
		}
	case r.Hunt != nil:
		c.hunt(at, r.Hunt.Target, r.Hunt.Grid)
	case r.Fix != nil:
		c.fix(at, r)
	case r.Sort != nil:
		c.sort(at, r.Sort.Bins, r.Sort.Items)
	case r.Match != nil:
		if n := len(r.Match.Pairs); n < 2 || n > 6 {
			c.p.add(at, "match.pairs needs 2 to 6 pairs")
		}
		for i, p := range r.Match.Pairs {
			for _, side := range []*matchSide{p.A, p.B} {
				if side == nil || ((side.Text == nil || *side.Text == "") && side.Picture == nil) {
					c.p.add(at, "match.pairs[%d]: each side (a, b) needs a text or a picture", i)
					break
				}
			}
		}
	case r.Pop != nil:
		c.pop(at, r.Pop.Target, r.Pop.Others, r.Pop.Count)
	case r.Truth != nil:
		if r.Truth.Text == "" || r.Truth.Answer == nil {
			c.p.add(at, "truth needs a text and an answer (true or false)")
		}
	}
}

// fix: 3 to 12 items, at least one written wrong (mirror or upside, the
// whole item or the letter at "at") and one written right.
func (c *checker) fix(at string, r *roundDoc) {
	wrong, right := 0, 0
	for i, it := range r.Fix.Items {
		switch {
		case it.Text == "":
			c.p.add(at, "fix.items[%d].text is required", i)
		case it.Wrong == nil:
			right++
		case !fixWrongs[*it.Wrong]:
			c.p.add(at, "fix.items[%d].wrong %q is not one of mirror, upside (or null)", i, *it.Wrong)
		default:
			wrong++
		}
		if it.At != nil && (*it.At < 0 || *it.At >= len([]rune(it.Text))) {
			c.p.add(at, "fix.items[%d].at %d is not a letter of %q", i, *it.At, it.Text)
		}
	}
	if n := len(r.Fix.Items); n < 3 || n > 12 {
		c.p.add(at, "fix.items needs 3 to 12 items")
	} else if wrong == 0 || right == 0 {
		c.p.add(at, "fix.items needs items written wrong and items written right")
	}
}

// sort: one bin (the monster; items without a bin are not its food) or two
// or three baskets (every item has one, every basket gets something).
func (c *checker) sort(at string, bins, items []sortThing) {
	if len(bins) < 1 || len(bins) > 3 {
		c.p.add(at, "sort.bins needs 1 to 3 bins")
		return
	}
	for i, b := range bins {
		if b.Label == "" {
			c.p.add(at, "sort.bins[%d].label is required", i)
		}
	}
	if len(items) < 2 || len(items) > 10 {
		c.p.add(at, "sort.items needs 2 to 10 items")
	}
	used := map[int]bool{}
	for i, it := range items {
		switch {
		case it.Label == "":
			c.p.add(at, "sort.items[%d].label is required", i)
		case it.Bin == nil && len(bins) > 1:
			c.p.add(at, "sort.items[%d] needs a bin (only the monster leaves food out)", i)
		case it.Bin != nil && (*it.Bin < 0 || *it.Bin >= len(bins)):
			c.p.add(at, "sort.items[%d].bin %d is not a bin", i, *it.Bin)
		case it.Bin != nil:
			used[*it.Bin] = true
		}
	}
	if len(used) < len(bins) {
		c.p.add(at, "sort: every bin needs at least one item")
	}
}

// pop: the target, at least one other label (never the target) and how
// many targets to pop (1 to 10).
func (c *checker) pop(at, target string, others []string, count int) {
	switch {
	case target == "":
		c.p.add(at, "pop.target is required")
	case len(others) == 0:
		c.p.add(at, "pop.others needs at least one label")
	case count < 1 || count > 10:
		c.p.add(at, "pop.count must be 1 to 10")
	}
	for _, o := range others {
		if o == target || o == "" {
			c.p.add(at, "pop.others must be labels other than the target")
			break
		}
	}
}

// hunt: a grid of 4 to 16 cells with the target in it at least once and at
// least one cell that is not the target.
func (c *checker) hunt(at, target string, grid []string) {
	found, other := 0, 0
	for _, cell := range grid {
		if cell == target {
			found++
		} else {
			other++
		}
	}
	switch {
	case target == "":
		c.p.add(at, "hunt.target is required")
	case len(grid) < 4 || len(grid) > 16:
		c.p.add(at, "hunt.grid needs 4 to 16 cells")
	case found == 0 || other == 0:
		c.p.add(at, "hunt.grid needs the target and at least one other cell")
	}
}

func (c *checker) pick(at string, p *pickDoc) {
	if len(p.Options) == 0 {
		c.p.add(at, "pick.options needs at least one option")
	}
	labels := map[string]bool{}
	ids := map[string]bool{}
	for _, o := range p.Options {
		if o.ID == "" || ids[o.ID] {
			c.p.add(at, "every option needs its own id (%q)", o.ID)
		}
		ids[o.ID] = true
		labels[o.Label] = true
		if o.Color != nil && !colors[*o.Color] {
			c.p.add(at, "option color %q is not one of red, blue, yellow, green, purple", *o.Color)
		}
	}
	if s := p.Stage; s != nil && !stages[*s] {
		c.p.add(at, "pick.stage %q is not one of house, count, stars", *s)
	}
	switch {
	case p.Answer == nil:
		c.p.add(at, "pick.answer is required")
	case p.Answer.Kind == "any":
	case p.Answer.Kind == "label":
		if p.Answer.Value == nil || !labels[*p.Answer.Value] {
			c.p.add(at, "pick.answer.value must be the label of one of the options")
		}
	default:
		c.p.add(at, `pick.answer.kind must be "label" or "any"`)
	}
}

// setBody stores the delivery document with its gzip copy and ETag.
func (c *Course) setBody(body []byte) {
	sum := sha256.Sum256(body)
	version := hex.EncodeToString(sum[:])[:16]
	var gz bytes.Buffer
	w, _ := gzip.NewWriterLevel(&gz, gzip.BestCompression)
	_, _ = w.Write(body)
	_ = w.Close()
	c.JSON, c.Gzip = body, gz.Bytes()
	c.ETag = `"` + version + `"`
	c.Summary.Version = version
}
