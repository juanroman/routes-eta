# api/ — Route ETA backend (Phase 1)

A small FastAPI app that backs the `web/` route builder, plus a checker that
fetches live ETAs and sends a Pushover notification (prd.md FR-11..28):

- `POST /preview` — given origin, destination and via points, calls Google
  Routes API and returns the path geometry (no persistence).
- `GET /config` / `PUT /config` — read and save the config (one or more named
  commutes, each with its own origin, destination, routes and schedule).
- `POST /run-now` — given a commute name, fetch a traffic-aware ETA for every
  one of its saved routes and send one Pushover notification now, ignoring
  the schedule.
- `uv run python -m app.cli run-now --commute NAME` / `... crontab` — the
  same checker run for one named commute, and a generated cron script
  covering every commute's schedule, for the Raspberry Pi (which doesn't run
  the API at all — FR-28).

## Setup

```
uv sync
```

Requires in a `.env` file at the repo root (copy `.env.example`):
- `GOOGLE_ROUTES_API_KEY` — needed by `/preview`, `/run-now` and the CLI's
  `run-now`. `/config` and the CLI's `crontab` work without any key.
- `PUSHOVER_APP_TOKEN` / `PUSHOVER_USER_KEY` — needed by `/run-now` and the
  CLI's `run-now`.

## Running

```
uv run uvicorn app.main:app --reload
```

Binds to `127.0.0.1:8000` only (never `0.0.0.0`), so only the local machine
can reach it. CORS is restricted to `WEB_ORIGIN` (default
`http://localhost:5173`, Vite's dev port).

## Checker, notification and scheduling (FR-11..22)

A config holds any number of named **commutes** (e.g. "Work to Home", "Home
to Work"), each with its own origin, destination, routes and list of
schedule rules (a schedule rule is a set of weekdays plus one time — a
commute can have more than one, e.g. an earlier Monday departure and a later
Tuesday–Friday one).

Manual run for one commute, from either the builder ("Send ETAs now") or the
command line:

```
uv run python -m app.cli run-now --commute "Work to Home"
```

Fetches a traffic-aware ETA for every route on that commute independently (one
failing route doesn't block the rest — it shows as `Name ?`), formats one
message prefixed with the commute's name (`Work to Home: Mordor 50 · City 56
· Toll Road 63`, or `Work to Home: Couldn't fetch ETAs` if every route
failed), and sends it via Pushover.

To run unattended on a schedule, generate and install a cron entry for every
commute and schedule rule in the config:

```
uv run python -m app.cli crontab
# CRON_TZ=America/Mexico_City
# 30 18 * * 1,2,3,4,5 cd /path/to/api && uv run python -m app.cli run-now --commute 'Work to Home' >> /path/to/api/checker.log 2>&1
# 30 6 * * 1 cd /path/to/api && uv run python -m app.cli run-now --commute 'Home to Work' >> /path/to/api/checker.log 2>&1
# 30 7 * * 2,3,4,5 cd /path/to/api && uv run python -m app.cli run-now --commute 'Home to Work' >> /path/to/api/checker.log 2>&1

# Install it (replaces any previous lines for this command, keeps everything else):
(crontab -l 2>/dev/null | grep -v 'app.cli run-now'; uv run python -m app.cli crontab) | crontab -
```

`CRON_TZ` is honored by Debian/Raspberry Pi OS's cron, so every job fires at
the configured local time regardless of the Pi's system timezone. If your
cron ignores `CRON_TZ`, set the Pi's system timezone to match instead
(`sudo raspi-config`). Output is appended to `checker.log` (gitignored) since
cron's own mail delivery is usually unconfigured on a headless Pi.

**Re-run the install one-liner above whenever a commute's schedule changes —
including adding, renaming or deleting a commute** (FR-21): cron jobs refer to
a commute by name, so a rename leaves behind a stale job that will fail to
find that commute at its next scheduled run, and a deleted commute's old job
would do the same.

## Config files

- `config.example.yaml` — tracked, illustrative placeholder route, same shape
  as `phase0/config.yaml`. Never read by the app.
- `config.yaml` — the real config, created by `PUT /config` the first time you
  save routes in the builder. Gitignored, since it encodes your real home/work
  location.

## Testing

```
uv run pytest                 # unit tests, mocked Google/Pushover — no network, no key
uv run pytest -m integration  # hits the real Google Routes API and (if configured) Pushover
```

**Call budget:** a full `pytest -m integration` run makes 3 real Google Routes
calls (1 preview, 1 traffic-aware duration, 1 via the `/run-now` endpoint) and
at most 1 real Pushover send — both skip cleanly if their respective
credentials aren't set. Each test is individually named after what it proves;
see `tests/integration/` docstrings.

## One-command check

```
./check.sh
```

Runs black (format check), ruff (lint), mypy (strict type check), pytest
(unit), and pip-audit, in that order. All must pass before a PR.
