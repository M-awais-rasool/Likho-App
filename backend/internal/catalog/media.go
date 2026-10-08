package catalog

import (
	"encoding/json"
	"sort"
	"strings"
)

// PicturePath is where a picture key's image is in the media folder.
func PicturePath(key string) string { return "pictures/" + key + ".png" }

// LipPath is the mouth-movement file next to a compressed recording.
func LipPath(audio string) string {
	if i := strings.LastIndex(audio, "."); i > strings.LastIndex(audio, "/") {
		return audio[:i] + ".lip"
	}
	return audio + ".lip"
}

// MediaPaths are the media files the course shows or plays, sorted: every
// recording (and its .lip), every picture key, the pictures of story strips
// (order tiles in "panel" slots) and of My Story's choices.
func (c *Course) MediaPaths() []string {
	var doc struct {
		Levels []map[string]any `json:"levels"`
	}
	if err := json.Unmarshal(c.JSON, &doc); err != nil {
		return nil
	}
	set := map[string]bool{}
	var walk func(v any)
	walk = func(v any) {
		switch x := v.(type) {
		case map[string]any:
			if a, ok := x["audio"].(string); ok && !strings.HasPrefix(a, "http") {
				set[a], set[LipPath(a)] = true, true
			}
			if p, ok := x["picture"].(map[string]any); ok {
				if k, ok := p["key"].(string); ok && p["url"] == nil {
					set[PicturePath(k)] = true
				}
			}
			if o, ok := x["order"].(map[string]any); ok && o["slot"] == "panel" {
				for _, t := range strSlice(o["tiles"]) {
					set[PicturePath(strings.ReplaceAll(t, " ", "_"))] = true
				}
			}
			if p, ok := x["pick"].(map[string]any); ok && p["choiceKey"] != nil {
				for _, o := range anySlice(p["options"]) {
					if m, ok := o.(map[string]any); ok {
						if l, ok := m["label"].(string); ok {
							set[PicturePath(l)] = true
						}
					}
				}
			}
			for _, child := range x {
				walk(child)
			}
		case []any:
			for _, child := range x {
				walk(child)
			}
		}
	}
	for _, l := range doc.Levels {
		// a level whose slot is "panel" puts its order tiles in panels too
		if pres, ok := l["presentation"].(map[string]any); ok && pres["slot"] == "panel" {
			for _, r := range anySlice(l["rounds"]) {
				if m, ok := r.(map[string]any); ok {
					if o, ok := m["order"].(map[string]any); ok {
						for _, t := range strSlice(o["tiles"]) {
							set[PicturePath(strings.ReplaceAll(t, " ", "_"))] = true
						}
					}
				}
			}
		}
		walk(l)
	}
	out := make([]string, 0, len(set))
	for p := range set {
		out = append(out, p)
	}
	sort.Strings(out)
	return out
}

func anySlice(v any) []any {
	s, _ := v.([]any)
	return s
}

func strSlice(v any) []string {
	var out []string
	for _, x := range anySlice(v) {
		if s, ok := x.(string); ok {
			out = append(out, s)
		}
	}
	return out
}
