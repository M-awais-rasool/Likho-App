# Likho

**Likhna seekho, khel khel mein.** English handwriting for 5 to 8 year olds: children trace, write
and play through a map of worlds with Pencil, the mascot, while parents follow along.

This repository holds the whole product:

```
Likho/
├── app/          Flutter app (iOS + Android)              → app/README.md
├── backend/      Go API + the learning content (JSON)     → backend/README.md
│   └── content/  courses, worlds, levels                  → backend/content/README.md
├── design/       prototype and mascot art the app is built from
├── docs/         how the pieces fit together              → docs/architecture.md
├── landing/      website: landing page, privacy, terms     → landing/README.md
├── tools/        course pictures (illustrations/) and Pencil's voice (voice/), Python
└── .github/      CI for the app and the backend
```

## How it fits together

```
                  ┌────────────────────────────────────────────┐
  Flutter app ───►│ Likho API (Go, Gin)                        │
  (app/)          │  /v1/courses/{id}  ← backend/content/*.json│
                  │  /v1/auth/google   ← Google Sign-In        │
                  │  /v1/me, /children ← Postgres (GORM)       │
                  │                    ← Redis (cache, limits) │
                  └────────────────────────────────────────────┘
```

* **One sign-in:** "Continue with Google". No sign-up, no passwords.
* **Content is data:** courses live as JSON in `backend/content/`, one file per level. The API
  checks and serves them; the app downloads a course once and again only when it changes.
* **Each child has their own progress** in every course, saved on the server. The app shows changes
  at once and keeps finished levels in a queue until the server has them (it works offline).
* **Try first:** without an account a child can play the warm-up and level 1 (nothing is saved).

More in [docs/architecture.md](docs/architecture.md).

## Quick start

Requirements: Flutter 3.47+, Go 1.27+, Docker (for Postgres and Redis).

```bash
# 1. the API
cd backend
cp .env.example .env          # DEV_LOGIN=true lets you sign in without Google
make db                       # Postgres + Redis
make run                      # http://localhost:8080

# 2. the app (another terminal)
cd app
flutter run --dart-define=LIKHO_DEV_EMAIL=me@example.com
```

The iOS simulator reaches the API as `localhost`, the Android emulator as `10.0.2.2` (the debug
defaults). For a real phone add `--dart-define=LIKHO_API=http://<this computer's IP>:8080`.

## Everyday tasks

| task | where |
|---|---|
| Add a level, world or course | `backend/content/` ([guide](backend/content/README.md)), then `make content` |
| Add a picture for the content | key in `tools/illustrations/build_illustrations.py`, then run it |
| Record Pencil's new or changed lines | `tools/voice/generate_voice.py` (Kokoro voice, `--print` checks pronunciations) |
| Change an API endpoint | `backend/internal/api/` → service → repository; update `backend/docs/openapi.yaml` |
| Change a screen | `app/lib/screens/` ([app guide](app/README.md)) |
| Run all tests | `cd app && flutter test` · `cd backend && make test-db` |

## Before production

* Google OAuth client IDs: `GOOGLE_CLIENT_IDS` (API), `GOOGLE_IOS_CLIENT_ID` /
  `GOOGLE_SERVER_CLIENT_ID` (app build), the iOS URL scheme in `app/ios/Runner/Info.plist`.
* The API address for release builds (`ApiConfig` in `app/lib/data/api/api_client.dart`).
* Store purchases for Likho Plus (the 7-day trial works today).
