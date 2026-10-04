# Likho Admin

The team's control panel for Likho: who uses the app and from where, how far every child got,
live activity, alerts when children run out of levels, and adding or editing levels with a
**real phone preview** before they go live.

React + TypeScript + Vite + Tailwind, talking to the Go API's admin endpoints
(`/admin/api/v1`, see `backend/README.md`). In production the API serves the built panel at
`/admin/` (`ADMIN_DIR`), so the panel and its API share one origin and one HttpOnly cookie.

## What it does

| Page | |
|---|---|
| Overview | Families, learners, active families (day/week/month), Likho Plus, levels and stars, children at the end of the course, countries, devices, app versions, ages, a per-level funnel, latest alerts and activity |
| Families | Every parent account: country, device, app version, children, levels done, stars, plan, last seen. Search, filters, sorting, CSV export |
| Family detail | Each child's stars on every level, star balance, devices, settings, activity. Give or end Likho Plus, adjust stars, sign out every device, delete the account |
| Learners | Every child with progress (on the last level / finished / not started) |
| Live activity | Sign-ups, sign-ins, finished levels (stars, time), course finished, room purchases, trials, as they happen (5 s) |
| Alerts | A child reached the last level (or N levels before it) or finished the course; optional sign-up and trial alerts. Bell badge, toast, sound and browser notifications |
| Levels & content | Every world and level with its status (live, draft, unpublished changes) and how children do on it. Add levels and worlds |
| Level editor | Form editor (level, intro, rounds: pick, write, order, speak) and raw JSON, checked against the whole course while you type, with the real app playing the level in a phone frame (several iPhone/Android sizes, level or map view). Save draft, publish, discard, unpublish, revert |
| Level insights | Finishes, players on each level now, average stars, 1-star rate, average time, where children stop |
| Team, Audit log, Settings, System | Owners, editors and viewers; every change logged; alert rules, notifications, password; database and Redis health |

Roles: **viewer** reads everything, **editor** also edits content and helps families, **owner**
also manages the team and deletes accounts.

## Run it locally

```bash
cd backend && docker compose up -d postgres redis      # databases
cd backend && make run                                  # API on :8080 (needs ADMIN_BOOTSTRAP_* in .env)
cd admin && npm install && npm run dev                  # panel on http://localhost:5173/admin/
```

The first owner is created from `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` in
`backend/.env` when there are no admins yet; add the rest of the team in **Team**.

### The phone preview

The preview is the Flutter app itself (`app/lib/preview/preview_main.dart`) compiled for the web.
Build it once, and again after app changes:

```bash
admin/scripts/build-preview.sh       # -> admin/public/preview (not committed)
```

The editor posts the course, with the level being edited, to the preview frame
(`postMessage`, same origin only). The preview plays it with a sample child who finished every
earlier level and has Likho Plus. Without the build the editor shows how to make it.

### Production

```bash
cd backend && make admin              # npm ci + phone preview + vite build -> admin/dist
ADMIN_DIR=../admin/dist               # the API serves it at /admin/
```

Serve the API over HTTPS in production: the session cookie is `Secure` when `APP_ENV=production`.

## How adding a level works

1. **Add level** picks the world (the last one, or a new world added in the panel) and a level to
   copy. Numbers only grow: children's progress is saved by level number, so levels are never
   renumbered.
2. The editor checks the level with the same rules as `make content` (ids unique in the course,
   answers are options, guides exist, numbering without gaps).
3. **Save** keeps a draft (phones do not see it). **Publish** checks the whole course again and
   swaps the content the API serves, without a restart; the course version (ETag) changes, so
   phones download it the next time the app opens. Other API servers reload within 15 s.
4. Built-in levels (the files in `backend/content`) can be edited too; **Revert** goes back to
   the file. A new level can be unpublished while no child has finished it.

New words have no recording, so the phone's text-to-speech voice reads them. To add recorded
voice later, write the level into `backend/content` and run `tools/voice/generate_voice.py`.
