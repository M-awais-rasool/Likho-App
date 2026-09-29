# Architecture

How the app, the API and the content fit together. Each part has its own details:
[app](../app/docs/architecture.md) · [API](../backend/README.md) ·
[content](../backend/content/README.md) · [API contract](../backend/docs/openapi.yaml).

## Repository

A monorepo: one pull request can change the app, the API and the content together, and CI checks
each part when it changes (`.github/workflows/`).

| folder | owns | built with |
|---|---|---|
| `app/` | everything on the phone: screens, game, mascot, sound, offline queue | Flutter, Riverpod |
| `backend/` | accounts, progress, rules, content delivery | Go, Gin, GORM, Postgres, Redis |
| `backend/content/` | what children learn: courses → worlds → levels → rounds | JSON + JSON Schema |
| `design/` | the prototype and mascot art (reference only) | — |

## Content pipeline

```
 author edits JSON                API start-up                      app
 backend/content/courses/…  ──►  catalog: load · check · build  ──►  GET /v1/courses/{id}
 (one file per level,            one document per course,          ETag → download only when
  schema in the editor)          gzipped, in memory                 changed; saved for offline
        │
        └─ make content (CI too): every problem, with its file
```

* **Authoring format ≠ delivery format.** Authors work with small files (a level per file, JSON
  Schema autocomplete, clean diffs in review). Phones get one document per course, the shape the
  app parses, built and verified by the server.
* **Checked before it ships.** Unknown fields, duplicate ids, gaps in numbering, broken references
  (a guide missing from `glyphs.json`, an answer that is not an option) fail `make content`, CI,
  and API start-up.
* **Versioned by content.** A course's version is a hash of its document: it changes exactly when
  the content does, and the app re-downloads only then.
* **Drafts.** A course with `"status": "draft"` is served in development only.
* **Contract test.** `app/test/fixtures/english-handwriting.json` is the course exactly as the API
  serves it (`make content-fixture`); the app's tests use it and CI fails if it is stale.

## Data ownership

| data | source of truth | on the phone |
|---|---|---|
| courses | `backend/content/` (Git) | saved copy of the last download |
| account, settings, subscription | Postgres `parents` | snapshot for offline start (`me.json`) |
| children, stars, room | Postgres `children`, `child_items` | shown instantly, confirmed by the API |
| progress | Postgres `level_progress` (child × course × level) | queue of unsent results (`pending_results.json`) |
| guest ("try first") | nowhere | memory only |

The server applies the same rules as the app (stars, unlocks, Likho Plus, shop prices), so the app
can show changes immediately and the server's answer corrects any difference.

## Request flow (a finished level)

```
app: recordResult  → shows stars at once, queues {course, level, stars, key}
     flush          → POST /v1/children/{child}/courses/{course}/results   Idempotency-Key: key
API: middleware     → auth (JWT) · rate limit · idempotency (a retry gets the first answer)
     handler        → parse
     service        → course exists? level exists? stars 1..3? (catalog)
     repository     → one transaction: lock child · unlocked? · Plus? · best stars · award · play day
     → outcome {gain, bestStars, totalStars}; /me cache dropped
app: applies the server's totals when nothing else is queued for that child
```

## Environments

| | app | API |
|---|---|---|
| development | `flutter run` (debug → `localhost:8080`, `LIKHO_DEV_EMAIL` sign-in) | `make run`, `DEV_LOGIN=true`, drafts served |
| production | release build → `https://api.likho.app` (placeholder), Google Sign-In | Docker image (`backend/Dockerfile`), `APP_ENV=production` |
