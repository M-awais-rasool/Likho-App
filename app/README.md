# Likho app

The Flutter app (iOS and Android). It talks to the Likho API in [`../backend`](../backend/README.md)
and plays the course served from [`../backend/content`](../backend/content/README.md).

## Run

```bash
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
| `LIKHO_TEST_EMAIL` | the account behind the Welcome screen's "Test User se login" button (default `test.user@likho.app`); signs in through the API's `DEV_LOGIN` like a Google account |
| `LIKHO_TEST_LOGIN` | `true` shows the "Test User" button in a release build too (debug and profile builds always show it) |

## Structure

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
│   └── dev/             debug-only: mascot playground, reference overlay, deep links
├── test/                widget + data tests; fixtures/ = the course as the API serves it
├── assets/              mascot, sounds, course pictures (illustrations/), Pencil's voice (voice/),
│                        reference captures (debug)
├── tool/                asset generators: sound_design/ (sound effects), mascot_trace/ (mascot art),
│                        app_icon/ (iOS and Android app icons); course pictures and Pencil's voice: ../tools/
├── docs/                architecture.md, sound_and_haptics.md
├── android/ · ios/
```

Details: [docs/architecture.md](docs/architecture.md) · sound and vibration:
[docs/sound_and_haptics.md](docs/sound_and_haptics.md).

## Test

```bash
flutter analyze
flutter test
```

The tests use `test/fixtures/english-handwriting.json`, the course exactly as the API serves it.
After changing content, refresh it from `backend/` with `make content-fixture` (CI fails when it is
stale). `test/fake_backend.dart` is an in-memory API for the sign-in and sync tests.
