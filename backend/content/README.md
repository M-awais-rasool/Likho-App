# Learning content

Every course Likho teaches lives here as plain JSON files: one folder per course, one file per world
and per level. The API builds each course into one document at start-up and serves it at
`GET /v1/courses/{courseId}`. The app downloads it, keeps a copy, and downloads it again only when
it changes.

```
content/
├── schema/                              JSON Schemas (editors check every file while you type)
└── courses/
    └── english-handwriting/             one folder per course (folder name = course id)
        ├── course.json                  title, language, ages, status
        ├── glyphs.json                  letter guides to trace (SVG strokes)
        ├── placement.json               warm-up after adding a child (level 0, optional)
        └── worlds/
            ├── 01-letter-land/          NN = the world's order on the map
            │   ├── world.json           name, icon, theme, boss
            │   └── levels/
            │       ├── 01-balloon-pop.json      NN = the level number
            │       ├── 02-alphabet-train.json
            │       └── …
            └── 02-small-letter-cove/
                └── …
```

Every file starts with a `"$schema"` line pointing at its schema in `schema/`. It is only for
editors (VS Code etc. then show errors and autocomplete); the API removes it.

## Add a level

1. Copy a level file of the same kind into the world's `levels/` folder.
2. Give it the next `number` (and start the file name with it: `37-…json`), a new `id`, and new
   round ids (`<level id>-r1`, `-r2` …).
3. Check it: `make content` (from `backend/`).

Numbers run 1, 2, 3 … across the whole course, world after world. **Never renumber a published
level**: each child's progress is stored by level number. Add new levels at the end of the last
world, or in a new world.

## Add a world

Make a folder `worlds/NN-name/` with a `world.json` (`order` = NN) and at least one level. The map
needs a theme for it (`themeId`, see the app's `LikhoWorlds`).

## Add a course

Make a folder `courses/<course-id>/` with `course.json`, `glyphs.json` and `worlds/`. Keep
`"status": "draft"` while you work on it: drafts are served in development only. Set it to
`"published"` to ship. The app picks the course by id (`appCourseId` in
`app/lib/data/course_providers.dart`), and every child's progress is kept per course.

## Rounds

Each round has a `type` and an object with the same name:

| type | object | the child… |
|---|---|---|
| `pick` | `options`, `answer` (`label` = the right option's label, or `any`) | taps the right answer |
| `write` | `mode` (`trace`, `dots`, `free`, `missing`, `spell`), `guide` (key in `glyphs.json`) | writes on the pad |
| `order` | `tiles` in the right order | puts tiles in order |
| `speak` | `expected` | says it aloud |

`picture.key` is a picture in the app (`app/assets/illustrations/<key>.png`), or set
`picture.url`. Pencil says `prompt.say` (or `prompt.text` when they are the same) from the
recording in `prompt.audio`; without a recording the device voice reads it.

## Pictures and Pencil's voice

Every level's intro has a picture and a line Pencil says while it shows:

```json
"intro": {
  "text": "B", "word": "balloon",
  "say": "B! B is for balloon. Let's pop the B balloons!",
  "audio": "assets/voice/level-01-intro.m4a",
  "picture": { "key": "balloon", "label": "balloon", "url": null }
}
```

* **Pictures** are Fluent Emoji (3D, MIT) with a transparent background, one 256 x 256 PNG per
  key, made by `tools/illustrations/build_illustrations.py`. A new picture: add its key there
  (one emoji, or a scene of several), run the script, use the key here.
* **What Pencil says** is `say` (intro, prompt) or the prompt's `text`. Write `say` when the
  words on screen are not what to say: `"/b/"` → `"Which letter says {/b/|bʌ}?"`, `"c _ t"` →
  `"Cat! Which letter is missing?"`. `{shown|IPA}` gives a pronunciation: the device voice reads
  `shown`, recordings say the IPA (`"Trace small {a|ˈeɪ}"`: the letter, not the article).
* **Recordings** are made by `tools/voice/generate_voice.py` (Kokoro text-to-speech, on this
  computer): it records new and changed lines into `app/assets/voice/` and writes their `audio`
  paths here. Check pronunciations first with `--print` (shows each line's phonemes).

The app's tests fail when a picture key has no image or a line has no recording
(`app/test/media_test.dart`).

## Checks

`make content` (or `go run ./cmd/content validate`) reads every course, drafts included, and lists
**every** problem with its file:

* unknown or missing fields (a typo is an error, not a silent default)
* ids unique across the course (levels and rounds), course id = folder name
* world orders and level numbers 1, 2, 3 … without gaps, going up world by world
* file and folder names start with their number
* round payload matches its type, answers are one of the options, guides exist in `glyphs.json`
* `say` is not empty and its pronunciations are complete (`{shown|IPA}`), `audio` is an app asset
  (`assets/….m4a`) or a URL

The API runs the same checks at start-up and refuses to start with broken content. CI runs them on
every pull request.

## See what the app receives

```bash
make content-bundle                 # english-handwriting, pretty-printed
go run ./cmd/content list           # every course with its version
make content-fixture                # refresh the app's test copy after a content change
```

The version (and the `ETag` header) is a hash of the course document, so it changes exactly when
the content does.

## Importing from the prototype

`tools/prototype-import/import.js` created the first course from the design prototype
(`design/prototype/`). It overwrites `courses/english-handwriting/`, so once the JSON has been
edited by hand, edit the JSON instead.
