package domain

// Item in the Mascot Room shop (the app's ShopItem.all).
type Item struct {
	ID    string
	Price int
	Wear  bool // clothes Pencil wears; otherwise furniture placed in the room
}

var Items = map[string]Item{
	"party":  {"party", 8, true},
	"cap":    {"cap", 12, true},
	"wizard": {"wizard", 20, true},
	"round":  {"round", 10, true},
	"stars":  {"stars", 15, true},
	"scarf":  {"scarf", 12, true},
	"cape":   {"cape", 25, true},
	"crown":  {"crown", 40, true},
	"phones": {"phones", 18, true},
	"bow":    {"bow", 6, true},
	"lamp":   {"lamp", 10, false},
	"poster": {"poster", 14, false},
	"plant":  {"plant", 8, false},
	"rug":    {"rug", 16, false},
}

// ItemOrder is the shop's order (the app's ShopItem.all).
var ItemOrder = []string{"party", "cap", "wizard", "round", "stars", "scarf", "cape", "crown", "phones", "bow", "lamp", "poster", "plant", "rug"}

// Tap results.
const (
	Bought   = "bought"
	Worn     = "worn"
	TakenOff = "taken_off"
	Placed   = "placed"
	Removed  = "removed"
)

// Tap decides what tapping an item does (FamilyNotifier.tapItem): buy it if
// not owned (and affordable), otherwise wear / take off, place / remove.
// ok is false when the child cannot afford it.
func Tap(item Item, owned bool, stars int, wearing *string, placed bool) (action string, ok bool) {
	switch {
	case !owned && stars < item.Price:
		return "", false
	case !owned:
		return Bought, true
	case item.Wear && wearing != nil && *wearing == item.ID:
		return TakenOff, true
	case item.Wear:
		return Worn, true
	case placed:
		return Removed, true
	default:
		return Placed, true
	}
}
