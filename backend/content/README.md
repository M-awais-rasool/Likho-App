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
            │   ├── world.json           name, class, icon, theme, boss
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

## Classes

Every world is for one school class: `"grade"` is `kg`, `class-1`, `class-2` or `class-3`. A class
can have several worlds; classes go up the map without skipping one. Today:

| worlds | class |
|---|---|
| 1 Letter Land, 2 Small Letter Cove | `kg` |
| 3 Phonics Forest, 4 Word Town | `class-1` |
| 5 Sentence Sky | `class-2` |
| 6 Story Space | `class-3` |

On a child's map their own class plays in order, lower classes are open for revision, and higher
classes stay locked until a parent opens them.

More levels for a class = a new world with that class. Progress is stored by level number, so
today a world can only be added at the end of the map (the highest class, or a new one). A world in
the middle (more KG, say) would renumber every level after it: that needs progress stored by level
id first.

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

`prompt.audio` is a recording (asset path or URL); without it the device voice reads
`prompt.text`. `picture.key` is a bundled image (`app/assets/illustrations/<key>.png`), or set
`picture.url`.

## Checks

`make content` (or `go run ./cmd/content validate`) reads every course, drafts included, and lists
**every** problem with its file:

* unknown or missing fields (a typo is an error, not a silent default)
* ids unique across the course (levels and rounds), course id = folder name
* world orders and level numbers 1, 2, 3 … without gaps, going up world by world
* every world has a class; classes go up world by world without skipping one
* file and folder names start with their number
* round payload matches its type, answers are one of the options, guides exist in `glyphs.json`

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
