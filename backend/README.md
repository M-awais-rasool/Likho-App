# Likho API

Go · Gin · PostgreSQL (GORM) · Redis. The backend of the Likho app: Google sign-in, each child's
progress, the Mascot Room, the parent's settings, and the learning content (courses as JSON).

* **Sign-in is Google only.** No sign-up and no password: the first "Continue with Google" creates
  the account, every later one continues it.
* **Content is data.** Courses, worlds and levels are JSON files in [`content/`](content/README.md),
  validated and served by the API. Adding a lesson is adding a file; adding a course is adding a
  folder.
* **The server owns the rules.** It awards stars, checks unlocks and Likho Plus against the course
  content, and spends stars in the shop, so an edited app cannot cheat.

## Architecture

```
            HTTP request
                 │
   ┌─────────────▼──────────────┐   internal/api/router.go     every route, versioned under /v1
   │ router + middleware        │   internal/api/middleware/   request id + log, recovery, auth (JWT),
   └─────────────┬──────────────┘                              rate limits, idempotent retries
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

## Folder structure

```
backend/
├── cmd/
│   ├── api/            the API server (main.go only: config → app.Run)
│   └── content/        content tool: validate · list · bundle
├── content/            learning content: courses/<id>/… JSON + schema/ (built into the binary)
├── docs/openapi.yaml   the API contract
├── internal/
│   ├── app/            composition root: wires database, cache, content, services, router; runs the server
│   ├── config/         settings from environment variables (.env.example)
│   ├── database/       Postgres (GORM, pool, AutoMigrate) and Redis connections
│   ├── domain/         rules (stars, unlocks, shop, validation) and business errors; no dependencies
│   ├── model/          entity.go = database tables · dto.go = API JSON
│   ├── catalog/        loads content/, checks it, builds each course (JSON + gzip + ETag)
│   ├── repository/     data access, one repository per area: account, child, progress, room, session
│   ├── cache/          Redis: /me, idempotent replies, rate limits (fails open)
│   ├── service/        business layer: auth (Google, tokens), account, child, progress, room, course
│   └── api/            router.go · handler/ · middleware/
├── test/e2e/           the whole API over HTTP on a real Postgres
├── tools/prototype-import/   one-time import of the design prototype into content/
├── Dockerfile · docker-compose.yml · Makefile · .env.example
```

Go's `internal/` keeps everything but `cmd/` and `content/` private to this module.

## Run it

```bash
cp .env.example .env        # fill in GOOGLE_CLIENT_IDS and JWT_SECRET
make db                     # Postgres + Redis in Docker
make run                    # API on http://localhost:8080
```

Or everything in Docker: `make up`. `make help` lists every target. Tables are created and updated
at start-up (GORM AutoMigrate, under a Postgres lock so several servers can start together).

With `DEV_LOGIN=true` (development only; refused in production) the token `dev:<email>` signs in
without Google, e.g. `flutter run --dart-define=LIKHO_DEV_EMAIL=me@example.com`. The app's "Test User"
button uses it too (`dev:test.user@likho.app`): one shared test account that is found or created like a
Google account, so its children, progress and settings stay on the server between sign-ins.

## Content

Courses live in [`content/`](content/README.md): one folder per course, one file per world and
level, JSON Schemas for editors. At start-up the API loads every course, checks it (and refuses to
start if something is wrong), and keeps one ready-made document per course in memory.

```bash
make content          # check every course, list every problem with its file
make content-bundle   # what the app receives for a course
```

## API

The full contract is [`docs/openapi.yaml`](docs/openapi.yaml). Errors are always
`{"error": "<code>", "message": "<text>"}`.

| method | path | what |
|---|---|---|
| GET | `/v1/courses` | the catalog: every served course with its version |
| GET | `/v1/courses/{courseId}` | a whole course, gzipped, `ETag` (`If-None-Match` → 304) |
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

## Data

| table | what |
|---|---|
| `parents` | the account (Google user), settings, Likho Plus |
| `children` | up to 4 per parent; `stars` are shared by all courses |
| `level_progress` | best stars per child **per course** per level |
| `child_items` | Mascot Room purchases |
| `play_days` | one row per child per day (days played, minutes this week) |
| `sessions` | signed-in devices (refresh token hashes) |

Development databases from before per-course progress can be reset with `make db-reset`.

## Why it is fast

* **No database on auth:** the access token is a signed JWT.
* **Redis in front of Postgres:** `/v1/me` is served from Redis and rebuilt only after a change.
  Rate limits and idempotency live in Redis too. If Redis is down the API keeps working from
  Postgres.
* **GORM tuned for speed:** prepared statements cached per connection, no transaction around single
  writes, a pool sized to the CPU, only slow queries (> 200 ms) logged in production.
* **Few queries:** `/v1/me` loads any number of children in 4 queries.
* **Content from memory:** each course is built once at start-up, gzipped (≈ 9 KB), with an ETag.
* **Safe under load:** stars and purchases run in transactions that lock the child's row, so
  parallel requests never double-award or double-spend.

Measured on a laptop (Postgres, local): `GET /v1/me` ≈ 19,000 requests/s (p99 2 ms), a course
≈ 40,000 requests/s, saving a level result ≈ 2 ms.

Rate limits per minute: sign-in 30 per IP; signed-in requests 600 per account; results and room
taps 120 per account.

## Tests

```bash
make test       # unit tests: rules, content checks, tokens, Google verification
make test-db    # + the whole API on Postgres (race detector)
make lint
```
