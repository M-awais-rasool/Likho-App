# Likho architecture

```
assets/data/course.json ──► CourseRepository ──► courseProvider ──► screens
   (API-shaped content)      (asset today,         (Riverpod,
                              network later)        loaded once)
                                                       │
                             LevelSession (rules) ◄────┤  one per level being played
                                   │                   │
                     GameplayScreen + round views ─────┘
```

| Layer | Folder | What lives there |
|---|---|---|
| Content | `assets/data/course.json` | Worlds, levels, rounds, letter guides. Same JSON the course API will return. |
| Data | `lib/data/` | Typed models (`models/course_models.dart`), repositories (`repositories/`: course, auth), providers, the family (`family.dart`: children, their progress, purchases, settings, subscription, play session), shop items, child progress. |
| Game rules | `lib/game/` | `LevelSession` (rounds, mistakes, stars, hints, timing), writing judge, prompt voice. No UI code. |
| Screens | `lib/screens/` | Every prototype screen (list below), shared screen widgets (`common/`), navigation (`app_flow.dart`). |
| Mascot | `lib/mascot/` | Pencil rig, animations, lip-sync. |
| Feedback | `lib/feedback/` | Sound effects + haptics by meaning (`AppFeedback`), engines, gameplay feedback. See `docs/sound_and_haptics.md`. |
| Design | `lib/design/` | Tokens (every colour, size, font), icon registry, shared widgets, `motion.dart` (the prototype's CSS keyframes as widgets). |
| Dev | `lib/dev/` | Mascot playground, reference overlay, QA deep link. |

## Screens and navigation

`AppFlow` (lib/screens/app_flow.dart) is the only place that pushes routes:

```
Splash -> Welcome -> Sign up / Login (-> Forgot password) -> Who's playing
Welcome "pehle try karein" / new child -> Placement warm-up -> Placement done -> World Map
Who's playing (root) -> World Map -> Level intro -> Gameplay -> Level complete
                                                   -> map | Session end | Certificate (level 36)
World Map: avatar -> Child profile -> Sticker book (edit -> parent gate -> Edit child)
           room button -> Mascot room;  settings -> parent gate -> Parent dashboard
Parent dashboard -> Settings, Course progress, Paywall; Plus levels (13+) -> Paywall first
```

| Folder | Screens (prototype number) |
|---|---|
| `auth/` | 02 Welcome, 03 Sign up (+ email form), 04 Login, 05 Forgot password (+ sent) |
| `profiles/` | 06 Who's playing, 07 Add / Edit child (3 steps, delete) |
| `placement/` | 09 Placement done (the warm-up itself is Gameplay with `course.placement`) |
| `level_complete/`, `session_end/`, `certificate/` | 13 Level complete (3/2/1 stars, boss woken), 14 Session end, 18 Certificate |
| `room/`, `profile/`, `stickers/` | 15 Mascot room, 16 Child profile, 17 Sticker book |
| `parent/` | 19 Dashboard, 20 Course progress, 21 Settings, 22 Paywall, 23 Parent gate |

Debug builds can open any screen directly (the prototype's side menu):
`echo room > "$(xcrun simctl get_app_container booted com.likho.likho data)/Documents/likho_dev_screen"`
(keys in `AppFlowJump.screens`), or from the mascot playground (long-press the REF chip).

Accounts, purchases and saving are not wired yet: `DemoAuthRepository` accepts any valid form after
1.2 s (swap `authRepositoryProvider` for the real backend), the family is in-memory demo data
(`FamilyNotifier`), and the paywall starts a trial without a store purchase.

## Content format (schemaVersion 1)

```jsonc
{
  "schemaVersion": 1,
  "worlds": [{ "id": "world-1", "order": 1, "name": "Letter Land", "icon": "grass", "themeId": "letterLand",
               "boss": { "id": "snail", "name": "Sust Ghonga" } }],
  "levels": [{
    "id": "level-01", "number": 1, "worldId": "world-1", "name": "Balloon Pop", "icon": "celebration",
    "isBoss": false, "requiresSubscription": false,
    "intro": { "text": "B", "word": "balloon", "picture": { "key": "balloon", "label": "balloon", "url": null } },
    "presentation": { "shape": "balloon", "slot": null, "pad": null, "layout": null, "stage": null },
    "rounds": [{
      "id": "level-01-r1", "type": "pick",
      "prompt": { "text": "Find B!", "audio": null },
      "card": { "text": "B", "picture": null, "listen": false },
      "pick": { "options": [{ "id": "…-o1", "label": "D" }, …], "answer": { "kind": "label", "value": "B" } }
    }]
  }],
  "glyphs": { "L": ["M40 20 L40 70", "M40 70 L64 70"] }
}
```

* Each round has a `type` and a payload object with the same name (`pick`, `write`, `order`, `speak`).
* `prompt.audio` = recording (asset path or URL). Without it the device voice reads `prompt.text`.
* `picture.key` = bundled image `assets/illustrations/<key>.png`; `picture.url` = remote image.
  Without either the prototype's labelled placeholder shows.
* Colours and icons are names (`themeId`, `icon`, pick option `color: "red"`), mapped to design tokens in the app.
* An unknown `type` from a newer API is skipped (the level still plays); a malformed field fails with its JSON path.

## Adding content

* **New level:** add it to `levels` (and its world). No code change. Presentation fields pick the look:
  `shape` (pick items), `slot` (order), `pad` (writing), `layout`, `stage`.
* **New letter to trace:** add its strokes to `glyphs` (100×100 box, baseline y = 70).
* **Pictures / voice:** drop `assets/illustrations/<key>.png`, or set `picture.url` / `prompt.audio`.

## Adding a new kind of game

1. Add a `Round` subclass + its `type` in `course_models.dart` (`Round.fromJson`).
2. Add its rules to `LevelSession` (an action method that ends in correct / wrong).
3. Add its view in `lib/screens/gameplay/rounds/` and one line in `_RoundArea` (gameplay_screen.dart).
   `Round` is sealed, so the app does not compile until step 3 is done.

## Switching to the API

Implement `CourseRepository` with an HTTP client (same JSON), cache the last response, fall back to
the bundled file offline, and return it from `courseRepositoryProvider`. Nothing else changes.

## Regenerating course.json from the prototype

`node tool/course_export/export_course.js` (reads `tool/course_export/prototype_data.js`, the data
embedded in `export/Likho-Prototype.html`). `tool/course_export/picture_keys.txt` lists every picture
the content needs.
