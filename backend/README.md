# Likho API

Go + Gin + PostgreSQL (GORM) + Redis. Sign-in is **Google only**: there is no sign-up and no
email/password. The first "Continue with Google" creates the account; every later one continues it.

## Folder structure

```
backend/
├── main.go          start here: config → Postgres (+ tables) → Redis → course → routes → server
├── config/          every setting, read from environment variables (.env.example)
├── database/        Postgres through GORM (pool, AutoMigrate) and Redis
├── models/          tables.go = database tables (GORM structs), api.go = JSON the app sends/receives
├── repository/      every database query (accounts, children, progress, sessions, course)
├── services/        logic: Google token check, our tokens, auth, Redis cache, course content
├── game/            Likho's rules (stars, unlocks, shop), the same as in the Flutter app
├── handlers/        HTTP: read request → check → repository/service → JSON
├── middleware/      auth, rate limits, request log, panics
└── routes/          every endpoint in one file
```

A request goes `routes → middleware → handlers → repository/services → database`.

## Run it

```bash
cp .env.example .env        # fill in GOOGLE_CLIENT_IDS and JWT_SECRET
make db                     # Postgres + Redis in Docker
make run                    # API on http://localhost:8080
```

Or everything in Docker: `make up`. Tables are created/updated automatically at start-up (GORM
AutoMigrate). `COURSE_FILE` (the app's `assets/data/course.json`) is imported into Postgres whenever
it changes.

Tests: `make test` (no database) or `make test-db` (also the full API flow on Postgres, with the race
detector).

## Google sign-in

1. Google Cloud Console → APIs & Services → Credentials: create OAuth client IDs for **iOS**,
   **Android** (package + SHA-1) and **Web**.
2. Put all of them in `GOOGLE_CLIENT_IDS`.
3. In Flutter (`google_sign_in`), pass the Web client ID as `serverClientId`, sign in, and send the
   `idToken` to `POST /v1/auth/google`.

The server checks the token itself (Google's signature with cached public keys, issuer, audience,
expiry, verified email), so a sign-in makes no call to Google.

With `DEV_LOGIN=true` (development only, refused in production) the token `dev:<email>` signs in
without Google, for trying the app before Google is set up.

## Tokens

| token | lives | how |
|---|---|---|
| access | 15 min | signed JWT in `Authorization: Bearer …`; checked without the database |
| refresh | 60 days | random, stored hashed; `POST /v1/auth/refresh` swaps it for a new pair |

A refresh token works once. If an already-swapped one comes back (it was copied), every session of
that account is signed out.

## API

Errors look like `{"error": "not_enough_stars", "message": "…"}`.

| method | path | what |
|---|---|---|
| POST | `/v1/auth/google` | `{"idToken"}` → tokens + `isNewAccount` + the whole account (`me`). 201 when new |
| POST | `/v1/auth/refresh` | `{"refreshToken"}` → new token pair |
| POST | `/v1/auth/logout` | sign this device out |
| GET | `/v1/me` | account, settings, subscription, children with progress (cached in Redis) |
| PATCH | `/v1/me/settings` | only the fields to change: `sessionMinutes` (5/10/15), `music`, `sfx`, `haptics`, `leftHanded`, `reduceMotion` |
| POST | `/v1/me/trial` | 7 days of Likho Plus, once |
| DELETE | `/v1/me` | delete the account and everything in it |
| POST | `/v1/children` | `{"name","age","color"}` (up to 4; name 1–14, age 5–8, one of the six Pencil colours) |
| PATCH | `/v1/children/:id` | change name / age / colour |
| DELETE | `/v1/children/:id` | not the only child |
| POST | `/v1/children/:id/results` | `{"level","stars","seconds"}` → `{gain, firstTime, bestStars, totalStars}`. Send an `Idempotency-Key` header |
| POST | `/v1/children/:id/room/:item` | Mascot Room tap: buy / wear / take off / place / remove |
| GET | `/v1/course` | course content, gzipped, ETag (`If-None-Match` → 304) |
| GET | `/healthz`, `/readyz` | up / Postgres + Redis reachable |

The server owns the rules: it awards stars (best result kept, +2 the first time), checks the level
is unlocked and, for levels 13+, the Likho Plus subscription, and spends stars in the shop, so the
app cannot be edited to cheat.

Example:

```bash
curl -X POST localhost:8080/v1/auth/google -d '{"idToken":"dev:ammi@gmail.com"}'
curl localhost:8080/v1/me -H "Authorization: Bearer $ACCESS"
curl -X POST localhost:8080/v1/children/$KID/results -H "Authorization: Bearer $ACCESS" \
  -H "Idempotency-Key: $(uuidgen)" -d '{"level":1,"stars":3,"seconds":140}'
```

## Why it is fast

* **No database on auth:** the access token is a signed JWT.
* **Redis in front of Postgres:** `/v1/me` is served from Redis and rebuilt only after a change.
  Rate limits and idempotency live in Redis too. If Redis is down the API keeps working from
  Postgres (it just gets a little slower).
* **GORM tuned for speed:** prepared statements cached per connection, no transaction around
  single writes, a connection pool sized to the CPU, and only slow queries (> 200 ms) logged.
* **Few queries:** `/v1/me` loads any number of children in 4 queries (children, level results, items,
  one aggregate for play days).
* **Course from memory:** already gzipped (≈ 9 KB), with an ETag so phones download it only when it
  changes.
* **Safe under load:** stars and purchases run in transactions that lock the child's row, so parallel
  requests never double-award or double-spend.

Measured on a laptop (Postgres 14, local): `GET /v1/me` ≈ 19,000 requests/s (p99 2 ms),
`GET /v1/course` ≈ 40,000 requests/s, saving a level result ≈ 2 ms.

## Rate limits

Per minute: sign-in 30 per IP; signed-in requests 600 per account; results + room 120 per account.
