# eink-dashboard deployment — design

**Date:** 2026-06-30
**Status:** Approved (brainstorm)
**Scope:** Phase 1 — deploy the eink-dashboard server as a headless, browser-viewable homelab docker stack integrated into docker-configs.

## Goal

Run the `eink-dashboard` **server** (renders a grayscale `dashboard.png`, serves over HTTP) as a docker stack on the homelab docker host `192.168.10.13`, integrated into the `docker-configs` repo, reachable internally at `https://dash.plexlab.site` (LAN + Twingate). Validate it renders correctly with real config (Snoqualmie weather, local timezone). Physical display, task capture, and voice are later phases.

## In scope

- Integrate `eink-dashboard` into `docker-configs` via **git subtree** at `homelab/eink-dashboard/`.
- Docker-configs-side deployment config (Traefik labels, `.env`, TZ) kept out of the subtree.
- Small upstream **TZ fix** in `eink-dashboard` so the header date is local, not UTC.
- Deploy on `.13`, expose via Traefik internal-only, verify the rendered dashboard + run the test suite.

## Out of scope (later phases)

- **#2 task capture without glasses** — own brainstorm (options: phone camera → Syncthing → inbox; Telegram/WhatsApp bot via existing `/bot`; web/PWA form).
- Raspberry Pi + Boox 32" physical display.
- WhatsApp voice bot, real Claude vision, Syncthing ingestion.

## Architecture

### 1. Repo integration — git subtree

```
git subtree add --prefix homelab/eink-dashboard \
  git@github.com:AnandSingh/eink-dashboard.git main
```

- Whole `eink-dashboard` repo content lands at `docker-configs/homelab/eink-dashboard/`.
- `eink-dashboard` remains the dev source of truth. Update: `git subtree pull --prefix homelab/eink-dashboard <url> main`. Push fixes upstream: `git subtree push --prefix homelab/eink-dashboard <url> main`.
- Deploys via the existing docker-configs homelab flow (sync to `.13` + `docker compose`).

### 2. Deployment config (docker-configs-side, NOT in the subtree)

Kept separate so `subtree pull` stays conflict-free:

- **`homelab/eink-dashboard/docker-compose.override.yml`** — docker compose auto-merges this with the subtree's base `docker-compose.yml`. Adds:
  - Traefik labels for `dash.plexlab.site` (internal), entrypoint `websecure`, TLS via the existing Cloudflare resolver, service port `8080`.
  - `TZ=America/Los_Angeles` env.
  - `restart: unless-stopped` (already in base; keep).
  - Healthcheck against `/healthz`.
- **`homelab/eink-dashboard/.env`** (gitignored, like other stacks) — the personal config below.
- **`homelab/eink-dashboard/.env.example`** — committed reference (already exists from subtree; extend if needed).

> Note: the subtree's base `docker-compose.yml` publishes `8080:8080` and mounts `./data`. The override adds Traefik labels + TZ; we rely on the Traefik `proxy` network. Confirm the base compose joins the `proxy` network (add via override if not).

### 3. TZ fix (small upstream code change to eink-dashboard)

The app derives the header date from the container clock (`datetime.now()` / `date.today()`), which is UTC in `python:3.12-slim`. Fix in the `eink-dashboard` repo:
- Add `tzdata` to the Dockerfile `apt-get install` line.
- Ensure the container honors the `TZ` env (tzdata + `TZ` is sufficient for `datetime.now()` local time; no code change needed beyond installing tzdata and setting `TZ`).
- Commit upstream, then `subtree pull` into docker-configs.

`CALENDAR_TZ` remains separate (only affects the calendar banner).

### 4. Runtime

- One `server` container on `.13`, built from `homelab/eink-dashboard/server` (subtree source).
- Volume: `homelab/eink-dashboard/data → /data` (SQLite DB + `dashboard.png`). Persist + include in backup.
- Port `8080` internal only; exposed solely via Traefik.
- Weather: manual Snoqualmie lat/lon, °F (IP-geolocation is wrong on a homelab host).
- Vision: `mock` (no API key needed for Phase 1). Demo data seeds on first empty boot → renders immediately.

### 5. Access

- Traefik router: `dash.plexlab.site → eink-dashboard:8080`, internal-only (resolvable on LAN + via Twingate), **no auth** (trusted network; the app has none).
- `/healthz` for the Traefik healthcheck.
- **Dependency:** `dash.plexlab.site` must resolve internally to `.13`. This ties into the open TODO "AdGuard not resolving plexlab.site" — resolve that (AdGuard rewrite `*.plexlab.site → 192.168.10.13`) or confirm resolution before/at deploy.

## Configuration (`.env`)

```ini
# Core
TZ=America/Los_Angeles
VISION_PROVIDER=mock
DATA_DIR=/data
API_PORT=8080

# Display (Boox 32")
PANEL_WIDTH=2560
PANEL_HEIGHT=1440

# Weather — Snoqualmie, WA (manual; IP geoloc wrong on homelab)
WEATHER_ENABLED=true
WEATHER_UNITS=fahrenheit
WEATHER_LAT=47.5287
WEATHER_LON=-121.8254
WEATHER_POLL_MINUTES=30

# Widgets / personal
BOTTOM_LEFT_WIDGET=quarter
MOON_ENABLED=true
SUNDAY_REVIEW=true
DAILY_TICK_MINUTES=60
# BIRTHDATE=            # optional, enables life-in-weeks
# COUNTDOWNS=           # optional, e.g. "Diwali:2026-11-08"

# Calendar (optional; empty = off)
CALENDAR_ICS_URL=
CALENDAR_TZ=America/Los_Angeles
```

## Verification

1. Deploy on `.13` (manual first: `docker compose up -d --build` in the stack dir).
2. Browse `https://dash.plexlab.site` (and/or `http://192.168.10.13:8080/dashboard.png`) → dashboard shows: **local date** (PT, not UTC), **Snoqualmie weather** in the header, **quarter** widget bottom-left, **moon + Ekadashi** footer, **demo tasks/habits/goals**.
3. `/healthz` returns healthy; `/version` returns an integer; re-hitting shows the version only bumps when pixels change (change-gated render).
4. Run tests: `cd homelab/eink-dashboard/server && python -m pytest tests/` — 13 test files should pass.
5. Commit the subtree + deployment config to docker-configs; confirm the existing homelab CI/deploy flow picks it up.

## Risks / notes

- **DNS:** blocked on `plexlab.site` internal resolution (existing TODO) — must be resolvable to reach via `dash.plexlab.site`; `http://192.168.10.13:8080` works regardless as a fallback for validation.
- **No auth:** acceptable because internal + Twingate only. Do NOT expose publicly without an auth layer.
- **Weather egress:** the container calls Open-Meteo directly; ensure `.13` has outbound internet (it does).
- **Subtree first-add** brings the whole eink-dashboard repo (server + pi-client + docs). That's fine; only `server/` is built.
