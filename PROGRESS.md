# Progress log

Tracks where Phase 1 actually is, across sessions. See `prd.md` for the
requirements this implements. Phase 0 is done (`phase0/results.md`).

## Status: Phase 1, slice 2 — done

Slice 2 = checker + Pushover notification + scheduler + the `/run-now`
endpoint and builder button (FR-11..22, FR-26). Slice 1 (route builder +
minimal backend) was already done; see below.

Branch: `feature/phase-1-route-builder`, no remote configured for this repo
yet.

### What's built (slice 2)

- **`api/app/checker.py`** — `check_all_routes()`: one independent
  traffic-aware `computeRoutes` call per route (`fetch_route_duration()` in
  `google_routes_client.py`, `TRAFFIC_AWARE` + `routes.duration` field mask
  only). One route failing never blocks the rest; `CheckerError` is reserved
  for a config that isn't complete enough to check at all (no origin/
  destination, or zero routes) — a different kind of failure than a single
  route's Google call failing.
- **`api/app/pushover.py`** — `format_message()` (FR-16/17: `Name minutes`
  joined by ` · `, `Name ?` on a per-route failure, `Couldn't fetch ETAs` if
  every route failed) and `send_notification()` (real Pushover POST).
- **`api/app/runner.py`** — `run_now()` ties load_config → checker → pushover
  together; this is the one function both the CLI and the API endpoint call.
- **`api/app/scheduler.py` + `app/cli.py`** — `uv run python -m app.cli
  run-now` (manual send, FR-22) and `... crontab` (prints a `CRON_TZ=...` +
  cron-line pair built from `config.yaml`'s schedule, FR-20/21). The CLI is
  what runs on the Raspberry Pi; it needs no JSON API there (FR-28).
- **`POST /run-now`** (FR-26) — `CheckerError` → 400, `PushoverError` → 502,
  success → 200 with the sent message and per-route results.
- **`web/`** — "Send ETAs now" button next to Save, showing the sent message
  or the error text, same status-state pattern as the existing Save button.
- 23 new `api/` unit tests (checker, pushover, runner, scheduler, cli, the
  `/run-now` endpoint — all mocked) + 3 new integration tests: the
  via+traffic-aware contract check promoted from Phase 0
  (`fetch_route_duration` against the real Google API), a web-to-API check
  (`/run-now` against the real Google API with only the Pushover send
  mocked), and one real Pushover send (the only real-send call site in the
  suite, deliberately — see its docstring). 4 new `web/` tests (client +
  button). `./check.sh` green across both projects.
- Manually verified against the real Google API and the owner's real
  `config.yaml`: clicked "Send ETAs now" in the builder, got a real
  traffic-aware ETA for all three routes, and a clear `Could not send ETAs:
  PUSHOVER_APP_TOKEN and PUSHOVER_USER_KEY must be set...` error — correct,
  since Pushover credentials aren't in `.env` yet. **Not yet verified: an
  actual Pushover push arriving on a phone** — needs the owner to add
  `PUSHOVER_APP_TOKEN`/`PUSHOVER_USER_KEY` to `.env` first.

### Decisions made beyond/clarifying the PRD (slice 2)

- `NamedPoint` now inherits `LatLng` instead of duplicating `lat`/`lng`, so
  `config.origin`/`config.destination` type-check wherever the Google client
  expects a `LatLng` (needed for the checker to reuse it) — no behavior
  change.
- Scheduler mechanism: a generated cron line, not an in-process scheduler —
  matches the PRD's proposed default. Uses `CRON_TZ=` (honored by Debian/
  Raspberry Pi OS's cron) so the schedule's configured timezone is
  independent of the Pi's system timezone. `README.md` documents a
  non-destructive install one-liner (replaces only the previous line for
  this command); not something run automatically, since it edits the
  system crontab.
- Checker output is redirected to a gitignored `api/checker.log` in the
  generated cron command, since unattended cron mail is usually
  unconfigured on a headless Pi — otherwise slice 2 would be undebuggable
  on-device.
- `CheckerError` (incomplete config) vs. `PushoverError` (couldn't send) are
  distinct exceptions mapped to different HTTP statuses (400 vs. 502) on
  `/run-now` — neither is a per-route failure, which `check_all_routes`
  already absorbs into `Name ?` without raising.
- Integration tests split by what they actually prove, to keep the real-call
  budget small and avoid duplicating a real Pushover send: one contract
  test (via + traffic-aware), one wiring test (the endpoint, Pushover
  mocked), one real send (Pushover client only).

## Status: Phase 1, slice 1 — done

Slice 1 = route builder (`web/`) + the minimal backend (`api/`) it needs.

### What's built

- **`api/`** (FastAPI, `uv`): `POST /preview`, `GET/PUT /config`. Config
  schema/IO with a tracked `config.example.yaml` + gitignored real
  `config.yaml`, atomic writes. Google Routes client ported from
  `phase0/validate_api.py`. 23 unit tests (mocked Google) + 1 integration
  test (real API, skips without a key). black/ruff/mypy/pip-audit all green
  via `api/check.sh`.
- **`web/`** (React + TS + Vite + react-leaflet): click-to-set
  origin/destination, create/name/color/reorder/delete routes, click-to-add /
  drag / remove via points with debounced live preview, save/load. 25
  Vitest/RTL tests. Prettier/ESLint/`tsc --noEmit` (strict)/npm-audit all
  green via `web/`'s `npm run check`.
- Root `./check.sh` runs both.
- Manually verified end-to-end against the real Google key and the owner's
  real routes (Constituyentes, Puentes, Mordor) — saved, reloaded, confirmed
  round-trip through `api/config.yaml` (gitignored, never committed).
- UI polish after first manual pass: sidebar no longer overflows (route rows
  wrap instead of clipping), and overlapping routes (two routes sharing a
  road) render as separated parallel lines via a small constant-pixel offset
  computed through Leaflet's own projection — invisible when routes are far
  apart, only separates them where they'd otherwise coincide.

### Decisions made beyond/clarifying the PRD

- Build order: `web/` first, backed by the real minimal `api/` (not mocks) —
  the browser can never hold the Google key (FR-8), so even "frontend-first"
  needs a thin real backend from day one.
- No second API key: map tiles are free/keyless OSM; preview and the future
  ETA checker both reuse the one `GOOGLE_ROUTES_API_KEY`, always proxied
  through `api/`.
- Origin/destination are set via the UI (click-to-set), not handed to the
  assistant or hand-edited into YAML. Config starts completely empty.
- No address geocoding/search — deliberately out of scope, click-on-map only.
- FastAPI over Flask (Pydantic doubles as the config schema).
- Route reordering is up/down buttons, not drag-and-drop (no new dependency).
- Scaffold tooling swapped from Vite's current defaults to match PRD §11:
  TypeScript pinned to `~6.0.3` (the new TS 7.x native compiler isn't
  supported by `typescript-eslint` yet), oxlint replaced with ESLint +
  Prettier.
- Tried dash-pattern route differentiation for overlaps first; rejected as
  confusing (changes appearance even where routes don't overlap). Replaced
  with the pixel-offset approach described above, which only affects
  rendering — saved via-point coordinates are untouched.

### Repo hygiene fix (session start)

Phase 0's work existed only on `feature/phase-0-api-validation`, never merged
to `main`. Fixed by fast-forwarding `main` onto it, then branching Phase 1
from the updated `main`.

### Not built yet

- Known minor polish item, not yet fixed: a console a11y warning about form
  fields missing `id`/`name` attributes in `web/`.
- Pushover credentials aren't in `.env` yet, so an actual push to a phone has
  never been sent — only the real Google API calls and the clear failure
  path have been verified (see slice 2's "What's built" above).

### How to pick this back up

```
cd api && uv run uvicorn app.main:app --reload   # backend
cd web && npm run dev                            # builder, separate shell
./check.sh                                       # both projects' full checks
```

To finish verifying slice 2 for real: add `PUSHOVER_APP_TOKEN` and
`PUSHOVER_USER_KEY` to `.env`, click "Send ETAs now" in the builder (or `cd
api && uv run python -m app.cli run-now`), and confirm a push arrives. Then
`uv run python -m app.cli crontab` and install it on whichever machine runs
unattended (see `api/README.md`).

This doc plus the code and tests in `api/` and `web/` is the full picture —
no other plan file to track down.
