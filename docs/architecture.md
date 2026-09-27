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
| Data | `lib/data/` | Typed models (`models/course_models.dart`), repository (`repositories/`), providers, child progress. |
| Game rules | `lib/game/` | `LevelSession` (rounds, mistakes, stars, hints, timing), writing judge, prompt voice. No UI code. |
| Screens | `lib/screens/` | Splash, World Map, Level Intro, Gameplay (+ one view per round type), navigation (`app_flow.dart`). |
| Mascot | `lib/mascot/` | Pencil rig, animations, lip-sync. |
| Design | `lib/design/` | Tokens (every colour, size, font), icon registry, shared widgets. |
| Dev | `lib/dev/` | Mascot playground, reference overlay, QA deep link. |

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
