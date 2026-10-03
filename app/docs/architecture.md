# App architecture

The Flutter app (`app/`). For how it fits with the API and the content, see
[../../docs/architecture.md](../../docs/architecture.md).

```
backend/content/courses/  ──► GET /v1/courses/{id} ──► ApiCourseRepository ──► courseProvider ──► screens
   (JSON, built into the API)   (ETag, gzip)          (saved on the phone,       (Riverpod,
                                                        offline copy)             loaded once)
                                                                                 │
                                       LevelSession (rules) ◄────┤  one per level being played
                                             │                   │
                               GameplayScreen + round views ─────┘

Google Sign-In ──► authProvider ──► familyProvider ──► screens      (each child's progress)
                   (POST /v1/auth/google,  (GET /v1/me; changes shown at once,
                    tokens, GET /v1/me)     then sent to the API)
```

| Layer | Folder | What lives there |
|---|---|---|
| Content | `../backend/content/` | Courses → worlds → levels → rounds, one JSON file per level. Served by `GET /v1/courses/{id}`; the app plays `appCourseId` (`lib/data/course_providers.dart`). |
| API | `../backend/` | Go API: Google sign-in, accounts, children, progress per course, room, settings, the content. |
| Data | `lib/data/` | API client (`api/`: tokens, refresh, errors, every endpoint, small files on the phone), sign-in (`auth.dart`), typed course models, the course repository, the family (`family.dart`: children, their progress, purchases, settings, subscription, play session), shop items, child progress. |
| Game rules | `lib/game/` | `LevelSession` (rounds, mistakes, stars, hints, timing), writing judge, prompt voice. No UI code. |
| Screens | `lib/screens/` | Every prototype screen (list below), shared screen widgets (`common/`), navigation (`app_flow.dart`). |
| Mascot | `lib/mascot/` | Pencil rig, animations, lip-sync. |
| Feedback | `lib/feedback/` | Sound effects + haptics by meaning (`AppFeedback`), engines, gameplay feedback. See `docs/sound_and_haptics.md`. |
| Design | `lib/design/` | Tokens (every colour, size, font), icon registry, shared widgets, `motion.dart` (the prototype's CSS keyframes as widgets). |
| Dev | `lib/dev/` | Mascot playground, reference overlay, QA deep link. |

## Screens and navigation

`AppFlow` (lib/screens/app_flow.dart) is the only place that pushes routes:

```
Splash -> (signed in) Who's playing, or Add child for a new account
       -> (signed out) Welcome -> "Continue with Google" -> Who's playing / Add child
Welcome "Try it first" / new child -> Placement warm-up -> Placement done -> World Map
Guest (not signed in): warm-up + level 1; level 2+, room, profile, parents -> Sign-in sheet
Who's playing (root) -> World Map -> Level intro -> Gameplay -> Level complete
                                                   -> map | Session end | Certificate (level 36)
World Map: avatar -> Child profile -> Sticker book (edit -> parent gate -> Edit child)
           room button -> Mascot room;  settings -> parent gate -> Parent dashboard
Parent dashboard -> Settings, Course progress, Paywall; Plus levels (13+) -> Paywall first
```

| Folder | Screens (prototype number) |
|---|---|
| `auth/` | 02 Welcome (one "Continue with Google" button), sign-in sheet for guests, the Google button |
| `profiles/` | 06 Who's playing, 07 Add / Edit child (3 steps, delete) |
| `placement/` | 09 Placement done (the warm-up itself is Gameplay with `course.placement`) |
| `level_complete/`, `session_end/`, `certificate/` | 13 Level complete (3/2/1 stars, boss woken), 14 Session end, 18 Certificate |
| `room/`, `profile/`, `stickers/` | 15 Mascot room, 16 Child profile, 17 Sticker book |
| `parent/` | 19 Dashboard, 20 Course progress, 21 Settings, 22 Paywall, 23 Parent gate |

Debug builds can open any screen directly (the prototype's side menu):
`echo room > "$(xcrun simctl get_app_container booted com.likho.likho data)/Documents/likho_dev_screen"`
(keys in `AppFlowJump.screens`), or from the mascot playground (long-press the REF chip).

## Pictures and voice

The course's pictures and Pencil's lines are app assets that the content names
(`backend/content/README.md` → Pictures and Pencil's voice):

* `assets/illustrations/<key>.png`: Fluent Emoji 3D (MIT, `assets/licenses/`), transparent, made
  by `../tools/illustrations/build_illustrations.py`. `Illustration` draws them (or the prototype's
  placeholder when one is missing); cards and shapes give them their background.
* `assets/voice/<id>.m4a` + `<id>.lip`: every intro line and round prompt, recorded by
  `../tools/voice/generate_voice.py` (Kokoro). `MascotController.say` plays a line and moves the
  mouth from its `.lip` file (loudness per 1/100 s); without a recording `PromptVoice` uses the
  device voice.
* The level intro waits for Pencil's line, then lifts away; a tap skips it.
* `test/media_test.dart` fails when a picture or a recording is missing.

## Accounts and saving

* **Sign-in** is Google only (`lib/data/auth.dart`): no sign up, no password. The first "Continue
  with Google" creates the account, later ones continue it. The refresh token is kept in the
  Keychain / Keystore, so the app opens signed in; the last account snapshot (`me.json`) lets it
  open offline too.
* **One course, each child's own progress.** The course is the same for everyone; stars, finished
  levels, the room and settings belong to each child / parent and live on the server.
* **Changes show at once** (`FamilyNotifier`, same rules as `backend/internal/domain`) and are then sent to the
  API; the server's answer corrects the numbers. Finished levels go through a queue saved on the
  phone (`pending_results.json`, each with an Idempotency-Key), so offline play is not lost and a
  resend never counts twice. The queue is sent after each level, when the app comes back to the
  front, and before logout. Something the server refuses is undone and explained with a toast.
* **Guests** ("Try it first") play with a phone-only child ("Friend"): nothing is sent or kept.
* **Session ended by the server** (logout elsewhere, account deleted) -> back to Welcome (`AppShell`).
* The paywall starts the 7-day trial on the server (`POST /v1/me/trial`); store purchases are not
  wired yet.
* Tests and the dev launchers use `DemoFamilyNotifier` (the prototype's sample family, never sent
  anywhere); `test/fake_backend.dart` is an in-memory API for the sign-in and sync tests.

Build settings (`--dart-define`):

| name | what |
|---|---|
| `LIKHO_API` | API address. Debug default: `http://localhost:8080` (Android emulator `http://10.0.2.2:8080`); release: `https://api.likho.app` |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client ID (also replace the URL scheme in `ios/Runner/Info.plist` with its reversed ID) |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client ID (Android needs it to get an ID token) |
| `LIKHO_DEV_EMAIL` | debug only: sign in as this email through the API's `DEV_LOGIN`, without Google |
| `LIKHO_TEST_EMAIL` | the account behind the Welcome screen's "Test User se login" button (default `test.user@likho.app`); signs in through the API's `DEV_LOGIN` like a Google account |
| `LIKHO_TEST_LOGIN` | `true` shows the "Test User" button in a release build too (debug and profile builds always show it) |

## Content format (schemaVersion 1)

```jsonc
{
  "schemaVersion": 1,
  "worlds": [{ "id": "world-1", "order": 1, "name": "Letter Land", "icon": "grass", "themeId": "letterLand",
               "boss": { "id": "snail", "name": "Sleepy Snail" } }],
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

## Publishing new content

Edit the JSON in `backend/content/courses/` ([guide](../../backend/content/README.md)), run
`make content` and deploy the API: phones download the new version on their next start (the ETag
changes) and use their saved copy until then. After a content change, refresh the tests' copy with
`make content-fixture` (in `backend/`); CI checks it.
