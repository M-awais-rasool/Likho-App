# Likho

**Likhna seekho, khel khel mein.** English handwriting for 5 to 8 year olds: children trace, write
and play through a map of worlds with Pencil, the mascot, while parents follow along.

This repository holds the whole product, and this file is its only README.

**Contents:** [Layout](#repository-layout) · [How it fits together](#how-it-fits-together) ·
[Quick start](#quick-start) · [App](#app-flutter) · [API](#api-go) ·
[Learning content](#learning-content) · [Admin panel](#admin-panel) · [Website](#website) ·
[Design](#design) · [Everyday tasks](#everyday-tasks) · [Before production](#before-production)

## Repository layout

```
Likho/
├── app/          Flutter app (iOS + Android); web build only for the admin preview
├── backend/      Go API + the learning content (JSON)
│   └── content/  courses, worlds, levels
├── admin/        admin panel (React): families, progress, alerts, level editor
├── landing/      website: landing page, privacy, terms, account deletion
├── design/       prototype and mascot art the app is built from
├── docs/         how the pieces fit together (architecture.md), Play Store listing
├── tools/        the course's levels (curriculum/), pictures (illustrations/) and Pencil's voice (voice/), Python
├── media/        what tools/ makes: pictures/ and voice/ (not in git; served by the API, see below)
├── deploy/       production on one server: docker-compose.yml, nginx, deploy.sh
└── .github/      CI for the app, the backend and the admin panel
```

## How it fits together

```
                  ┌────────────────────────────────────────────┐
  Flutter app ───►│ Likho API (Go, Gin)                        │
  (app/)          │  /v1/courses/{id}  ← backend/content/*.json│
                  │  /v1/auth/google   ← Google Sign-In        │
                  │  /v1/me, /children ← Postgres (GORM)       │
  Admin panel ───►│  /admin/api/v1     ← Redis (cache, limits) │
  (admin/)        └────────────────────────────────────────────┘
```

* **One sign-in:** "Continue with Google". No sign-up, no passwords.
* **Content is data:** courses live as JSON in `backend/content/`, one file per level. The API
  checks and serves them; the app downloads a course once and again only when it changes. Levels
  can also be added from the admin panel.
* **Each child has their own progress** in every course, saved on the server. The app shows changes
  at once and keeps finished levels in a queue until the server has them (it works offline).
* **Try first:** without an account a child can play the warm-up and level 1 (nothing is saved).

More in [docs/architecture.md](docs/architecture.md).

## Quick start

Requirements: Flutter 3.47+, Go 1.27+, Docker (for Postgres and Redis), Node 20+ (admin, website).

```bash
# 1. the API
cd backend
cp .env.example .env          # DEV_LOGIN=true lets you sign in without Google
make db                       # Postgres + Redis
make run                      # http://localhost:8080

# 2. the app (another terminal)
cd app
flutter run --dart-define=LIKHO_DEV_EMAIL=me@example.com

# 3. the admin panel (optional)
cd admin && npm install && npm run dev        # http://localhost:5173/admin/

# 4. the website (optional)
cd landing && npm install && npm run dev      # http://localhost:3000
```

The iOS simulator reaches the API as `localhost`, the Android emulator as `10.0.2.2` (the debug
defaults). For a real phone add `--dart-define=LIKHO_API=http://<this computer's IP>:8080`.

---

## App (Flutter)

The iOS and Android app. It talks to the [API](#api-go) and plays the course served from
[`backend/content`](#learning-content).

```bash
cd app
flutter pub get
flutter run --dart-define=LIKHO_DEV_EMAIL=me@example.com   # with the API running (backend: make run)
```

Build settings (`--dart-define`):

| name | what |
|---|---|
| `LIKHO_API` | API address. Debug default: `http://localhost:8080` (Android emulator `http://10.0.2.2:8080`); release: `https://api.likho.app` (placeholder) |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client ID (also put its reversed ID in `ios/Runner/Info.plist`) |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client ID (Android needs it for an ID token) |
| `LIKHO_DEV_EMAIL` | debug only: sign in as this email through the API's `DEV_LOGIN`, without Google |
| `LIKHO_TEST_EMAIL` | the account behind the Welcome screen's "Sign in as Test User" button (default `test.user@likho.app`); signs in through the API's `DEV_LOGIN` like a Google account |
| `LIKHO_TEST_LOGIN` | `true` shows the "Test User" button in a release build too (debug and profile builds always show it) |

Every request also sends `X-Likho-Platform`, `X-Likho-App-Version` (`appVersion` in
`lib/data/api/api_client.dart`, kept in step with `pubspec.yaml` by a test) and `X-Likho-Region`
(the phone's region), which the admin panel shows.

```
app/
├── lib/
│   ├── main.dart        start: sound + haptics, splash, app shell
│   ├── data/            API client, sign-in, course + family state (server-backed, offline queue)
│   ├── game/            level rules (LevelSession), writing judge, prompt voice; no UI
│   ├── screens/         every screen; navigation in app_flow.dart; shared widgets in common/
│   ├── mascot/          Pencil: rig, animations, lip-sync
│   ├── feedback/        sound effects and haptics by meaning
│   ├── design/          tokens (colours, sizes, fonts), motion
│   ├── preview/         web-only level preview for the admin panel
│   └── dev/             debug-only: mascot playground, reference overlay, deep links
├── test/                widget + data tests; fixtures/ = the course as the API serves it
├── assets/              mascot, sounds, licences, reference captures (debug); the course's
│                        pictures and voice come from the server (lib/data/media.dart)
├── tool/                asset generators: sound_design/, mascot_trace/, app_icon/
├── docs/                architecture.md, sound_and_haptics.md
├── android/ · ios/ · web/
```

The world map, sticker book and parent screens follow the course: any number of worlds and levels
per world. Details: [app/docs/architecture.md](app/docs/architecture.md) · sound and vibration:
[app/docs/sound_and_haptics.md](app/docs/sound_and_haptics.md).

### Tests

```bash
flutter analyze
flutter test
```

The tests use `test/fixtures/english-handwriting.json`, the course exactly as the API serves it.
After changing content, refresh it from `backend/` with `make content-fixture` (CI fails when it is
stale). `test/fake_backend.dart` is an in-memory API for the sign-in and sync tests.

### App icon (`app/tool/app_icon/`)

`build_app_icon.dart` draws the app icon: Pencil waving hello on a violet sky with soft rays and
sparkles, from the app's own mascot painter, every file from vectors at its exact pixel size.

```bash
cd app && flutter test tool/app_icon/build_app_icon.dart
```

It fails if Pencil leaves Android's safe zone (the 66 dp circle no launcher mask cuts). It writes:

| where | what |
|---|---|
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | 1024 px icons for the light, dark and tinted (iOS 18+) home screens, without an alpha channel. Xcode makes the other sizes. |
| `android/app/src/main/res/mipmap-*/` | adaptive layers `ic_launcher_background`, `_foreground`, `_monochrome` (Android 13 themed icons), plus `ic_launcher` and `ic_launcher_round` for Android 7 and older, in all five densities |
| `android/app/src/main/res/mipmap-anydpi-v26/` | `ic_launcher.xml`, `ic_launcher_round.xml` (stack the layers) |
| `design/app-icon/` | `google-play-512.png` for the Play listing, `likho-icon-1024.png` for anything else |

To change it, edit the constants at the top of the script (`_day`/`_night` sky colours,
`_height`/`_centre`/`_tilt` place Pencil, `_wave` his pose, `_sparkles`) and run it again.

### Mascot tracing (`app/tool/mascot_trace/`)

How `assets/mascot/*.svg` and `assets/reference/*.png` were made from the master art in
`design/mascot/`. Pure Python + Pillow; artboard 500 x 680 units = master pixels, origin at master
(454, 36). Run from that folder, in order (about 6 minutes):

| step | script | what it does |
|---|---|---|
| 0 | `prepare.py` | JPEG → PNG in `.work/` |
| 1 | `classify_master.py` | labels every master pixel with its nearest measured colour |
| 2 | `extract_master.py` | traces eraser+band, cone+graphite, legs, brows, cheeks, mouth |
| 3 | `fit_arms2.py` | fits the noodle-arm curves (quadratic Bézier + width) |
| 4 | `extract_master2.py` | body, rest hands, shadow, eye geometry → `rig.json` |
| 5 | `fit_eyes.py` | grid-search of eye radii (numbers copied into step 4 / `pencil_rig.dart`) |
| 6 | `trace_sheets.py` | mouths and hand poses, scaled to the master |
| 7 | `trace_accessories.py` | the 10 accessories |
| 8 | `trace_fx.py` | the three "z" letters from the sleepy cell |
| 9 | `export_assets.py` | writes the SVG parts + aligned reference overlays |

`compose.py` renders the idle pose and diffs it with the master. Rig numbers used by the app live in
`lib/mascot/rig/pencil_rig.dart`.

---

## API (Go)

Go · Gin · PostgreSQL (GORM) · Redis: Google sign-in, each child's progress, the Mascot Room, the
parent's settings, the learning content, and the admin panel's API.

* **Sign-in is Google only.** The first "Continue with Google" creates the account, every later one
  continues it.
* **Content is data.** Courses, worlds and levels are JSON files in `backend/content/`, validated
  and served by the API.
* **The server owns the rules.** It awards stars, checks unlocks and Likho Plus against the course
  content, and spends stars in the shop, so an edited app cannot cheat.

### Architecture

```
            HTTP request
                 │
   ┌─────────────▼──────────────┐   internal/api/router.go     every route (/v1, /admin/api/v1)
   │ router + middleware        │   internal/api/middleware/   request id + log, recovery, auth (JWT),
   └─────────────┬──────────────┘                              rate limits, idempotency, tracking
   ┌─────────────▼──────────────┐
   │ handler                    │   internal/api/handler/      HTTP only: read the request, call a
   └─────────────┬──────────────┘                              service, write JSON / map errors
   ┌─────────────▼──────────────┐
   │ service                    │   internal/service/          business logic: validation, rules,
   └──────┬───────────┬─────────┘                              cache invalidation, Google, tokens
          │           │
 ┌────────▼───┐ ┌─────▼──────┐ ┌──────────┐
 │ repository │ │ catalog    │ │ cache    │   repository = every SQL query (GORM)
 └────────┬───┘ └─────┬──────┘ └────┬─────┘   catalog    = courses from content/, in memory
      Postgres    content/ JSON    Redis      cache      = /me, idempotency, rate limits
```

Dependencies only point down: handlers never touch the database, repositories never know about
HTTP, and business errors (`internal/domain`) carry a stable code (`level_locked`) that the handler
turns into an HTTP status.

```
backend/
├── cmd/
│   ├── api/            the API server (main.go only: config → app.Run)
│   └── content/        content tool: validate · list · bundle
├── content/            learning content: courses/<id>/… JSON + schema/ (built into the binary)
├── docs/openapi.yaml   the app's API contract
├── internal/
│   ├── app/            composition root: wires database, cache, content, services, router; runs the server
│   ├── config/         settings from environment variables (.env.example)
│   ├── database/       Postgres (GORM, pool, AutoMigrate) and Redis connections
│   ├── domain/         rules (stars, unlocks, shop, validation) and business errors; no dependencies
│   ├── model/          entity.go = database tables · dto.go = API JSON
│   ├── catalog/        loads content/, checks it, builds each course (JSON + gzip + ETag); overlay, store
│   ├── geo/            country of a request (CDN header, GeoIP, phone region)
│   ├── repository/     data access, one repository per area
│   ├── cache/          Redis: /me, idempotent replies, rate limits (fails open)
│   ├── service/        business layer: auth, account, child, progress, room, course, activity, admin, content
│   └── api/            router.go · handler/ · middleware/
├── test/e2e/           the whole API over HTTP on a real Postgres
├── Dockerfile · docker-compose.yml · Makefile · .env.example
```

### Run

```bash
cd backend
cp .env.example .env        # fill in GOOGLE_CLIENT_IDS and JWT_SECRET
make db                     # Postgres + Redis in Docker
make run                    # API on http://localhost:8080
```

Or everything in Docker: `make up`. `make help` lists every target. Tables are created and updated
at start-up (GORM AutoMigrate, under a Postgres lock so several servers can start together).

With `DEV_LOGIN=true` (development only; refused in production) the token `dev:<email>` signs in
without Google. The app's "Test User" button uses it too (`dev:test.user@likho.app`): one shared
test account that is found or created like a Google account.

### Endpoints

The full contract is [`backend/docs/openapi.yaml`](backend/docs/openapi.yaml). Errors are always
`{"error": "<code>", "message": "<text>"}`.

| method | path | what |
|---|---|---|
| GET | `/v1/courses` | the catalog: every served course with its version |
| GET | `/v1/courses/{courseId}` | a whole course, gzipped, `ETag` (`If-None-Match` → 304) |
| GET | `/v1/media` | the media manifest: `{"files": {"voice/line-….m4a": "<hash>", …}}`, gzipped, `ETag` |
| GET | `/media/{path}?v={hash}` | a picture or recording; with its current hash cached for a year, ranges, 304 |
| POST | `/v1/auth/google` | `{"idToken"}` → tokens + `isNewAccount` + the whole account; 201 when new |
| POST | `/v1/auth/refresh` | `{"refreshToken"}` → new token pair |
| POST | `/v1/auth/logout` | sign this device out |
| GET | `/v1/me` | account, settings, subscription, children with progress per course (Redis-cached) |
| PATCH | `/v1/me/settings` | only the fields to change |
| POST | `/v1/me/trial` | 7 days of Likho Plus, once |
| DELETE | `/v1/me` | delete the account and everything in it |
| POST | `/v1/children` | `{"name","age","color"}`, up to 4 |
| PATCH / DELETE | `/v1/children/{childId}` | change / delete (not the only child) |
| POST | `/v1/children/{childId}/courses/{courseId}/results` | a finished level `{"level","stars","seconds"}` |
| POST | `/v1/children/{childId}/room/{itemId}` | Mascot Room tap: buy / wear / take off / place / remove |
| GET | `/healthz`, `/readyz` | process up / Postgres (and Redis) reachable |

Results and room taps accept an `Idempotency-Key` header: a retry gets the first answer again
(`Idempotent-Replay: true`) instead of counting twice.

```bash
curl -X POST localhost:8080/v1/auth/google -d '{"idToken":"dev:ammi@gmail.com"}'
curl localhost:8080/v1/me -H "Authorization: Bearer $ACCESS"
curl -X POST localhost:8080/v1/children/$KID/courses/english-handwriting/results \
  -H "Authorization: Bearer $ACCESS" -H "Idempotency-Key: $(uuidgen)" -d '{"level":1,"stars":3,"seconds":140}'
```

### Tokens

| token | lives | how |
|---|---|---|
| access | 15 min | signed JWT in `Authorization: Bearer …`; checked without the database |
| refresh | 60 days | random, stored hashed; `POST /v1/auth/refresh` swaps it for a new pair |

A refresh token works once. If an already-swapped one comes back (it was copied), every session of
that account is signed out.

### Google sign-in setup

1. Google Cloud Console → APIs & Services → Credentials: create OAuth client IDs for **iOS**,
   **Android** (package + SHA-1) and **Web**.
2. Put all of them in `GOOGLE_CLIENT_IDS`.
3. The app passes the Web client ID as `serverClientId` and sends the `idToken` to
   `POST /v1/auth/google`. The server checks it itself (Google's signature with cached public keys,
   issuer, audience, expiry, verified email), so a sign-in makes no call to Google.

### Data

| table | what |
|---|---|
| `parents` | the account (Google user), settings, Likho Plus, last seen, country, platform, app version |
| `children` | up to 4 per parent; `stars` are shared by all courses |
| `level_progress` | best stars per child **per course** per level |
| `child_items` | Mascot Room purchases |
| `play_days` | one row per child per day (days played, minutes this week) |
| `sessions` | signed-in devices (refresh token hashes) |
| `activity_events`, `active_days` | what families do and the days they use the app (admin panel) |
| `admin_users`, `admin_sessions`, `admin_alerts`, `admin_audit`, `admin_settings` | the admin panel |
| `content_levels`, `content_worlds` | levels and worlds written in the admin panel |

Development databases from before per-course progress can be reset with `make db-reset`.

### Why it is fast

* **No database on auth:** the access token is a signed JWT.
* **Redis in front of Postgres:** `/v1/me` is served from Redis and rebuilt only after a change.
  Rate limits and idempotency live in Redis too. If Redis is down the API keeps working from
  Postgres.
* **GORM tuned for speed:** prepared statements cached per connection, no transaction around single
  writes, a pool sized to the CPU, only slow queries (> 200 ms) logged in production.
* **Few queries:** `/v1/me` loads any number of children in 4 queries.
* **Content from memory:** each course is built once, gzipped (≈ 65 KB), with an ETag.
* **Media never asked twice:** pictures and recordings are indexed once at start-up; their URLs
  carry the file's hash, so the phone keeps each file forever and nginx can send it straight from
  the disk (`deploy/nginx/likho.conf`). The app downloads the next levels' files ahead.
* **Safe under load:** stars and purchases run in transactions that lock the child's row, so
  parallel requests never double-award or double-spend.

Measured on a laptop (Postgres, local): `GET /v1/me` ≈ 19,000 requests/s (p99 2 ms), a course
≈ 40,000 requests/s, saving a level result ≈ 2 ms. Rate limits per minute: sign-in 30 per IP;
signed-in requests 600 per account; results and room taps 120 per account; admin sign-in 10 per IP.

### Tests

```bash
make test       # unit tests: rules, content checks, tokens, Google verification, countries
make test-db    # + the whole API on Postgres, admin panel included (race detector)
make lint
```

---

## Learning content

Every course lives in `backend/content/` as plain JSON files: one folder per course, one file per
world and per level. The API builds each course into one document at start-up and serves it at
`GET /v1/courses/{courseId}`. The app downloads it, keeps a copy, and downloads it again only when
it changes.

```
backend/content/
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
            │       ├── 01-straight-lines.json   NN = the level number
            │       └── …
            └── 02-small-letter-cove/
                └── …
```

Every file starts with a `"$schema"` line pointing at its schema in `schema/`, for editors only (the
API removes it). Levels can also be written in the [admin panel](#admin-panel), without touching
these files.

**The course is generated.** All 12 worlds (144 levels) are written by
`tools/curriculum/build_levels.py` (worlds 1–2, the alphabet) and `tools/curriculum/later_worlds.py`
(worlds 3–12) from their tables:

| World | Levels | Teaches |
|---|---|---|
| 1 Letter Land | 1–31 | capitals A–Z, in alphabet order |
| 2 Small Letter Cove | 32–62 | small a–z and their sounds |
| 3 Phonics Forest | 63–71 | blending three-letter words, short vowels, rhymes |
| 4 Word Town | 72–79 | colours, numbers, animals, body, family, food, school |
| 5 Sound Mountain | 80–89 | sh ch th ck ng ee oo ai oa ar or |
| 6 Blend Beach | 90–96 | blends (st, fl, tr, -nd) and two-beat words |
| 7 Sight Word Garden | 97–104 | sight words (the, said, was, they …) |
| 8 Sentence Sky | 105–112 | spaces, capitals, full stops, a/an, plurals, sentences |
| 9 Action Jungle | 113–120 | doing and describing words, opposites, in/on/under, -ing |
| 10 Question Island | 121–128 | who/what/where, ? and !, days, talking |
| 11 Reading River | 129–136 | reading sentences and short passages |
| 12 Story Space | 137–144 | story order, writing about me, my story |

One new idea per level in 8 to 10 games, never two games of one kind in a level (the script
checks it), writing always on the one paper pad, a boss at the end of each world. So that no two
levels play alike, every level has at least two of the newer games (bubble pop, fix Pencil's
mistakes, the hungry monster or baskets, memory match, true or silly, writing from memory): in the
letter worlds each game slot (meet, sound, look, build, write) has a few games that teach the same
thing and turns with the level; in worlds 3–12 three new games are added to every level, starting
further along the list each time (`add_star_games` in `later_worlds.py`). The games the
course had before (Paint Shop, Doctor Pencil, Talk to Aliens, My Story …) are kept in
`tools/curriculum/classic_rounds.json` and played inside these levels. Change the plan there and
run it (`--check` prints the plan and the pictures still to draw), then draw the pictures and
record the new lines (below). World 1 is free; Likho Plus starts at level 32.

**Add a level.** Copy a level file of the same kind into the world's `levels/` folder, give it the
next `number` (and start the file name with it: `145-…json`), a new `id` and new round ids
(`<level id>-r1`, `-r2` …), then run `make content`. Numbers run 1, 2, 3 … across the whole course,
world after world. **Never renumber a published level**: each child's progress is stored by level
number. Add new levels at the end of the last world, or in a new world.

**Add a world.** Make a folder `worlds/NN-name/` with a `world.json` (`order` = NN) and at least one
level. `themeId` picks its look (`letterLand`, `smallLetterCove`, `phonicsForest`, `wordTown`,
`sentenceSky`, `storySpace`, `soundMountain`, `blendBeach`, `sightGarden`, `actionJungle`,
`questionIsland`, `readingRiver`) and `boss.id` its boss (`snail`, `fish`, `bear`, `robotBus`,
`cloud`, `moon`, `goat`, `crab`, `ladybug`, `monkey`, `turtle`, `frog`).

**Add a course.** Make a folder `courses/<course-id>/` with `course.json`, `glyphs.json` and
`worlds/`. Keep `"status": "draft"` while you work on it: drafts are served in development only.
Set it to `"published"` to ship. The app picks the course by id (`appCourseId` in
`app/lib/data/course_providers.dart`), and every child's progress is kept per course.

### Rounds

Each round has a `type` and an object with the same name:

| type | object | the child… |
|---|---|---|
| `pick` | `options`, `answer` (`label` = the right option's label, or `any`) | taps the right answer |
| `write` | `mode` (`trace`, `dots`, `free`, `flash`, `missing`, `spell`), `guide` (key in `glyphs.json`) | writes on the pad (`flash`: sees it for a moment, then writes it from memory) |
| `order` | `tiles` in the right order | puts tiles in order |
| `speak` | `expected` | says it aloud |
| `hunt` | `target`, `grid` (4–16 cells, the target among them) | taps every cell that is the target |
| `pop` | `target`, `others`, `count` (1–10) | pops the bubbles that say the target as they float up |
| `fix` | `items` (3–12: `text`, `wrong` = `mirror` / `upside` / null, `at` = the one wrong letter) | taps what Pencil wrote backwards or upside down |
| `sort` | `bins` (1–3), `items` (`label`, `picture`, `bin`) | drags things into bins: one bin is the hungry monster (`bin: null` = not food), two or three are baskets |
| `match` | `pairs` (2–6, sides `a` and `b` with `text` or `picture`) | turns cards to find the pairs (no mistakes) |
| `truth` | `text`, `picture`, `answer` | taps True or Silly |

Writing is always on the one ruled paper pad. A `pick` round can set its own `stage` and an `order`
round its own `slot`, instead of the level's. A card with `"listen": true` and no text or picture shows a speaker: the child hears the answer
instead of seeing it. Levels are 8 to 10 rounds; from 8 rounds Pencil cheers halfway, and a child
who leaves part way goes on from that round next time (kept on the phone for 7 days). Stars come
from the share of mistakes (`starsFor` in `app/lib/game/level_session.dart`).

`picture.key` is a picture on the server (`media/pictures/<key>.png`), or set `picture.url`.
Pencil says `prompt.say` (or `prompt.text` when they are the same) from the recording in
`prompt.audio`; without a recording the device voice reads it.

### Pictures and Pencil's voice

Every level's intro has a picture and a line Pencil says while it shows:

```json
"intro": {
  "text": "B", "word": "ball",
  "say": "{B|bˈiː}! {B|bˈiː} is for ball. Let's learn {B|bˈiː}!",
  "audio": "voice/line-174f3f68010c3535.m4a",
  "picture": { "key": "ball", "label": "ball", "url": null }
}
```

* **They live on the server, not in the app or git.** The tools write them to `media/` at the
  repository root (git-ignored); the API serves that folder (`MEDIA_DIR`) at `/media/` with a
  manifest at `/v1/media`. The app keeps every file it downloads (by hash, so it is never stale),
  fetches the next three levels ahead, plays offline what it has, and falls back to placeholders
  and the device voice for what it does not. `deploy/deploy.sh user@server media` sends new files.
* **Pictures** are Fluent Emoji (3D, MIT) with a transparent background, one 256 x 256 PNG per key,
  made by `tools/illustrations/build_illustrations.py` into `media/pictures/`. For a new picture
  add its key there (one emoji, or a scene of several), run the script, use the key in the content.
* **What Pencil says** is `say` (intro, prompt) or the prompt's `text`. Write `say` when the words
  on screen are not what to say: `"/b/"` → `"Which letter says {/b/|bʌ}?"`. `{shown|IPA}` gives a
  pronunciation: the device voice reads `shown`, recordings say the IPA (`"Trace small {a|ˈeɪ}"`:
  the letter, not the article).
* **Recordings** are made by `tools/voice/generate_voice.py` (Kokoro text-to-speech, on this
  computer): it records new and changed lines into `media/voice/` and writes their `audio` paths
  (`voice/line-….m4a`) into the content. A recording is named after what it says, so a line used by many levels
  is one file and renumbering levels records nothing. Check pronunciations first with `--print`.

`go run ./cmd/content media-check` (in `backend/`) fails when a picture or recording the content
uses is missing from the media folder; `deploy.sh` runs it first, and the API logs any it lacks at
start-up. The app's tests check every line has a recording, and the folder when it exists.

### Checks

`make content` (or `go run ./cmd/content validate`) reads every course, drafts included, and lists
**every** problem with its file: unknown or missing fields; ids unique across the course; course id
= folder name; world orders and level numbers 1, 2, 3 … without gaps, going up world by world; file
and folder names start with their number; round payload matches its type, answers are one of the
options, guides exist in `glyphs.json`; `say` is not empty and its pronunciations are complete;
`audio` is an app asset (`assets/….m4a`) or a URL. The API runs the same checks at start-up and
refuses to start with broken content. CI runs them on every pull request.

```bash
make content-bundle                 # what the app receives (english-handwriting, pretty-printed)
go run ./cmd/content list           # every course with its version
make content-fixture                # refresh the app's test copy after a content change
```

The version (and the `ETag` header) is a hash of the course document, so it changes exactly when
the content does.

---

## Admin panel

The team's control panel in `admin/` (React + TypeScript + Vite + Tailwind): who uses the app and
from where, how far every child got, live activity, alerts when children run out of levels, and
adding or editing levels with a **real phone preview** before they go live.

| page | |
|---|---|
| Overview | families, learners, active families (day / week / month), Likho Plus, levels and stars, children at the end of the course, countries, devices, app versions, ages, a per-level funnel, latest alerts and activity |
| Families | every parent account: country, device, app version, children, levels done, stars, plan, last seen; search, filters, sorting, CSV export |
| Family detail | each child's stars on every level, star balance, devices, settings, activity; give or end Likho Plus, adjust stars, sign out every device, delete the account |
| Learners | every child with progress (on the last level / finished / not started) |
| Live activity | sign-ups, sign-ins, finished levels (stars, time), course finished, room purchases, trials, as they happen |
| Alerts | a child reached the last level (or N levels before it) or finished the course; optional sign-up and trial alerts; bell badge, toast, sound and browser notifications |
| Levels & content | every world and level with its status (live, draft, unpublished changes) and how children do on it; add levels and worlds |
| Level editor | form editor (level, intro, rounds) and raw JSON, checked against the whole course while you type, with the real app playing the level in a phone frame (iPhone / Android sizes, level or map view); save draft, publish, discard, unpublish, revert |
| Level insights | finishes, players on each level now, average stars, 1-star rate, average time, where children stop |
| Team · Audit log · Settings · System | owners, editors and viewers; every change logged; alert rules, notifications, password; database and Redis health |

Roles: **viewer** reads everything, **editor** also edits content and helps families, **owner** also
manages the team and deletes accounts.

### Run it

```bash
cd backend && make db && make run                # API on :8080 (needs ADMIN_BOOTSTRAP_* in .env)
cd admin && npm install && npm run dev           # http://localhost:5173/admin/
admin/scripts/build-preview.sh                   # once, and after app changes: the phone preview
```

The first owner is created from `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` in
`backend/.env` when there are no admins yet; add the rest of the team in **Team**. The phone preview
is the Flutter app itself (`app/lib/preview/preview_main.dart`) built for the web into
`admin/public/preview` (not committed). The editor posts the course, with the level being edited, to
the preview frame (same origin only); it plays it with a sample child who finished every earlier
level and has Likho Plus.

**Production:** `cd backend && make admin` (npm ci + phone preview + build into `admin/dist`), then
`ADMIN_DIR=../admin/dist` makes the API serve the panel at `/admin/`, so the panel and its API share
one origin. Serve it over HTTPS: the session cookie is `Secure` when `APP_ENV=production`.

### How adding a level works

1. **Add level** picks the world (the last one, or a new world added in the panel) and a level to
   copy. Numbers only grow, because progress is saved by level number.
2. The editor checks the level with the same rules as `make content`.
3. **Save** keeps a draft (phones do not see it). **Publish** checks the whole course again and swaps
   the content the API serves without a restart; the course version changes, so phones download it
   the next time the app opens. Other API servers reload within 15 s.
4. Built-in levels (the files in `backend/content`) can be edited too; **Revert** goes back to the
   file. A new level can be unpublished while no child has finished it.

New words have no recording, so the phone's text-to-speech voice reads them. To record them, write
the level into `backend/content` and run `tools/voice/generate_voice.py`.

### Admin API

`/admin/api/v1`. Admins sign in with email and password (`POST /auth/login`, bcrypt); the session
is a random token in an HttpOnly, SameSite=Strict cookie (12 h, only its hash is stored), and every
change must also send `X-Requested-With: likho-admin`. Every change is written to `admin_audit`.

| area | endpoints |
|---|---|
| dashboard | `GET /overview?days=`, `GET /levels/stats`, `GET /activity?types=&after=&before=` |
| families | `GET /families` (search, country, filter, sort, paging), `GET /families.csv`, `GET /families/{id}`, `POST/DELETE /families/{id}/plus`, `POST /families/{id}/sign-out`, `DELETE /families/{id}` (owner), `POST /children/{id}/stars` |
| learners | `GET /learners` |
| alerts | `GET /alerts`, `GET /alerts/unread`, `POST /alerts/read`, `GET/PUT /settings/alerts` |
| content | `GET /courses`, `GET /content/courses/{id}`, `GET …/document` (preview), `GET …/levels/{n}`, `POST …/levels/validate`, `POST …/levels`, `PUT …/levels/{n}`, `POST …/levels/{n}/publish`, `…/unpublish`, `…/discard`, `DELETE …/levels/{n}`, `POST/PUT/DELETE …/worlds` |
| team | `GET/POST /team`, `PATCH/DELETE /team/{id}` (owner), `GET /audit`, `GET /system` |

**Activity and countries.** Signed-in requests mark the parent active (at most every 5 minutes, via
Redis): `last_seen_at`, today's `active_days` row, platform, app version and the country: the CDN's
header (`COUNTRY_HEADER`, e.g. `CF-IPCountry`), else the IP in a GeoIP database (`make geoip`,
`GEOIP_DB`; DB-IP Lite, CC BY 4.0: "IP Geolocation by DB-IP"), else the phone's region. Only the
country code is kept, never the IP. Deleting an account deletes its events (an anonymous
`account_deleted` stays).

**Alerts.** When a child finishes, for the first time, the level `levelsBeforeEnd` before the last
one (default: they are now on the last level), and when they finish the last level, an alert is
added once per child, course and level.

**Content from the panel.** New and edited levels live in `content_levels` (working copy + live
copy) and `content_worlds`, laid over `backend/content/` by `catalog.Overlay`, so they pass exactly
the same checks. Publishing swaps the served catalog (`catalog.Store`) and bumps the content
revision. If published content ever stops loading (e.g. a file in `content/` now clashes with a
level added in the panel), the API keeps serving the last good catalog and the panel lists the
problems.

---

## Website

The public site in `landing/`: the landing page, plus the privacy policy, the terms and the account
deletion page that Google Play and the App Store ask for. Next.js 16 (App Router), Tailwind CSS 4
and Framer Motion; every page is static.

```bash
cd landing
npm install
npm run dev        # http://localhost:3000;  npm run build · npm run lint
```

**Before going live**, fill in the placeholders in `landing/src/lib/site.ts`, the one place that
holds what the site says about Likho:

| field | now | set it to |
|---|---|---|
| `email` | `hello@example.com` | the address parents can write to (privacy and deletion pages) |
| `developer` | `Likho` | your name, or your business once it is registered |
| `playStoreUrl`, `appStoreUrl` | `null` ("Coming soon") | the store pages, once the app is live |
| `updated` | `3 October 2026` | the date whenever the privacy policy or terms change |

Course numbers and prices are in the same file; keep them in step with `backend/content` and the
app's paywall. Read the privacy policy and the terms once yourself before publishing.

**Deploy (Vercel):** on vercel.com **Add New → Project**, import this repository and set **Root
Directory** to `landing`. Add `NEXT_PUBLIC_SITE_URL` (e.g. `https://likho.app`; used by share
previews, the sitemap and canonical links) and deploy; add your own domain under **Settings →
Domains**. Then give Google Play `https://<your site>/privacy` as the privacy policy and
`https://<your site>/delete-account` as the account deletion link.

```
landing/
├── src/app/          pages: / (landing), /privacy, /terms, /delete-account; sitemap, robots,
│                     icons and the share image (opengraph-image.png)
├── src/components/   one file per landing section, plus PhoneDemo and TracingPad (tracing demo)
├── src/lib/          site.ts (facts and links), glyphs.ts (the course's letter strokes)
└── public/           pencil/ (mascot art), pictures/ (course pictures), brand/ (app icon)
```

Pencil art comes from the app's mascot painter; the course pictures from `media/pictures/`
(192 px WebP); the icons from `design/app-icon/likho-icon-1024.png`; `glyphs.ts` is copied from the
course's `glyphs.json`, so the demo traces letters exactly as the app does. Animations follow the
visitor's "reduce motion" setting.

---

## Design

Reference material in `design/` that the app is built from; nothing here ships in the app.

| folder | what |
|---|---|
| `prototype/` | the clickable HTML prototype (`Likho-Prototype.html`) with screen and level captures in `screens/` and `levels/`. Screens, colours, copy and level data come from here. Older code comments call it `export/`. |
| `mascot/` | Pencil's master art sheets the app's mascot rig and accessories were traced from (see [mascot tracing](#mascot-tracing-apptoolmascot_trace)). Older code comments call it `mascot's/`. |
| `app-icon/` | store icons made by `app/tool/app_icon/` |

The first course was imported once from the prototype's level data; since then its JSON is edited
by hand. `app/assets/reference/` holds screen captures for the app's debug reference overlay.

---

## Everyday tasks

| task | where |
|---|---|
| Add a level, world or course | the [admin panel](#admin-panel), or `backend/content/` ([guide](#learning-content)) then `make content` |
| Add a picture for the content | key in `tools/illustrations/build_illustrations.py`, then run it |
| Record Pencil's new or changed lines | `tools/voice/generate_voice.py` (Kokoro voice, `--print` checks pronunciations) |
| Change the course plan | `tools/curriculum/` (tables), then the two tools above, then `make content-fixture` |
| Deploy | `deploy/deploy.sh user@server` ([guide](#deploy-one-server)); new media only: `… media` |
| Change an API endpoint | `backend/internal/api/` → service → repository; update `backend/docs/openapi.yaml` |
| Change a screen | `app/lib/screens/` ([app](#app-flutter)) |
| Run all tests | `cd app && flutter test` · `cd backend && make test-db` · `cd admin && npm run build` |

## Deploy (one server)

Everything runs on one server next to other projects, from `deploy/`:

* **`docker-compose.yml`:** Postgres, Redis and the API, each with a memory and CPU cap (512 MB,
  128 MB, 384 MB), restarting by themselves, 30 MB of logs at most. Only the API has a port, on
  `127.0.0.1` (`LIKHO_PORT`); Postgres and Redis are on Likho's own Docker network. Postgres is
  tuned for its share (128 MB shared buffers, 40 connections, the API uses at most 16), Redis is a
  96 MB cache with no disk, the API's Go heap is held under 300 MB. The API image is a static
  binary on distroless, read-only, with `likho-api health` as its health check.
* **`nginx/likho.conf`:** the site for your nginx: `/media/` straight from the disk (sendfile,
  cached a year), the rest to the API with keep-alive. Add HTTPS with certbot.
* **`deploy.sh user@server`:** checks the media, sends the media folder, the admin panel's build
  and the code (rsync, only what changed), builds and starts the containers, restarts the API so it
  indexes new media, and waits until it is ready. `deploy.sh user@server media` only sends media.

First time on the server: install Docker and rsync, run `deploy.sh` once (it creates
`/srv/likho/src/deploy/`), fill in `/srv/likho/src/deploy/.env` from `.env.example`, run it again,
then add the nginx site. Measured with the production image under Docker Desktop on a laptop:
36 MB of memory for the API, the course and the media manifest at 1,300–1,900 requests/s and a
picture at 900/s through Docker's network (a Linux server is several times faster, and nginx
serves the media itself).

## Before production

* Google OAuth client IDs: `GOOGLE_CLIENT_IDS` (API), `GOOGLE_IOS_CLIENT_ID` /
  `GOOGLE_SERVER_CLIENT_ID` (app build), the iOS URL scheme in `app/ios/Runner/Info.plist`.
* The API address for release builds (`ApiConfig` in `app/lib/data/api/api_client.dart`).
* Store purchases for Likho Plus (the 7-day trial works today).
* Admin panel: HTTPS, a strong `ADMIN_BOOTSTRAP_PASSWORD` (or add the team and remove it), and
  `COUNTRY_HEADER` or `GEOIP_DB` for countries.
* The website's placeholders in `landing/src/lib/site.ts`.
