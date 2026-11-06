# Progress log

Tracks where Phase 1 actually is, across sessions. See `prd.md` for the
requirements this implements. Phase 0 is done (`phase0/results.md`).

## iOS app (`ios/`) — standalone MVP, talks to Google directly

Native SwiftUI MVP: commute/routes editor + a "show ETAs" button, no push
notifications. Built mock-first (all UI against in-memory services), real
networking to `api/` in a later phase. Plan: Phase 0 project, Phase 1
skeleton + navigation, Phase 2 commute/routes editor, Phase 3 ETAs.

**Phase 0 (done):** `ios/RoutesETA/` (thin app target) + `ios/RoutesETAKit/`
(local package: `Domain`, `Mocks`, `Features`; `Domain`/`Mocks` stay
platform-neutral so a future watchOS target can reuse them). iOS 27.2, Swift 6,
strict concurrency `complete`, warnings as errors (verified: a deliberate
warning fails the build), Swift Testing, swift-format (strict) and SwiftLint
(strict, `brew install swiftlint`). `ios/check.sh` runs all of it; it is
deliberately **not** hooked into the root `check.sh`, which also runs on the
Raspberry Pi where Xcode doesn't exist. See `ios/README.md`.

**Phase 1 (done):** `Domain` models mirroring `api/app/config_models.py`
(same JSON keys), validation mirroring its validators (`ConfigIssue`), schedule
summaries ("Tue–Fri · 07:30"), and the `ConfigRepository` / `RoutePreviewService`
/ `ETAService` protocols. `Mocks`: `SampleData` (a contract test keeps it equal
to `fixtures/sample-config.json`), in-memory repository that rejects invalid
configs like the API's 422, deterministic preview and ETA mocks (a route named
"...fail..." fails, to exercise partial/all-failed UI). `Features`: `ConfigStore`
(validate, then persist; commutes get a stable UI id since names are renameable),
`AppRouter` (typed `NavigationStack` path), commutes list (add/rename/delete),
commute detail, and placeholder route/schedule editors. The app composes the
mocks in `RoutesETAApp`. Decision: list-level add/rename/delete persist
immediately; Phase 2's editors will add save/discard.

**Phase 2 (in slices; one PR each):**
- 2a commute basics (this PR): rename and delete (with confirmation) from the
  commute detail, origin/destination picker modeled on Calendar's Location field (real MapKit
  `MKLocalSearchCompleter`, in the new `Platform` target; mock for tests/UI tests)
  plus Maps-style Home/Work keyword shortcuts (iOS exposes no system Home/Work,
  so the app keeps its own, in UserDefaults; picking one copies coordinates into
  the commute), `ConfigStore.updateCommute` as the single
  validated write path for all editors.
- 2b routes list (this PR): add (opens the new route's editor, named "Route N"
  in the next palette color, like the web builder), rename + color in a route
  editor, swipe-delete with confirmation, reorder via Edit. Routes are addressed
  by index in navigation since the editor renames them.
- 2c schedule editor (this PR): per-rule weekday chips and a time picker; chips
  owned by another rule are disabled and a rule's last day can't be switched off,
  so overlap/empty rules can't be created (the store still validates);
  add/delete rule (delete confirmed); timezone shown as a footer.
- 2d MapKit via-point editor (this PR): the route editor now has a map on top
  (route line in its color, origin/destination markers, numbered handles) with
  the name/color/delete form below. Tap the line to add a via point (inserted in
  route order, ported from `web/src/map/polylineGeometry.ts`), drag a handle to
  move it (committed on release; the preview is re-requested, latest wins, and
  the old line stays visible while loading), tap a handle to select it and
  Remove. Cap of 23 via points. Spike findings are recorded in `RouteMapView`
  (use `.global` for `MapProxy.convert`; taps near a handle are ignored by the
  map handler). Preview still comes from the mock (straight lines); real Google
  routes arrive when `api/` is connected.

**Phase 3 (done, this PR):** "Show ETAs" on the commute screen opens a sheet with
one colored chip per route in config order (minutes, or "?" when that route
failed; quickest marked "Fastest"; "Updated HH:MM" and Refresh). All routes
failing shows "Couldn't fetch ETAs" with Try Again. The button is disabled with
a reason until the commute has origin, destination and a route. Still the mock
`ETAService` (a route named "...fail..." fails).

**Next (not started): connect the app to `api/`.** The editor still draws
straight origin-via-destination lines because the mock preview has no roads;
the real route comes from `POST /preview` (decoded polyline), which
`RouteMapView` already paints, so only a `URLSession` `RoutePreviewService` (plus
config and ETA clients) is needed. Decisions to make first:
- `api/` binds 127.0.0.1 only (prd FR-27): fine for the iOS Simulator
  (localhost), but a physical phone needs a reachable host plus auth.
- `POST /run-now` also sends the Pushover notification, so the app's ETA button
  needs either a new notify-free endpoint or to accept the notification.
(Considered and rejected: MapKit directions as a stopgap; its roads and via
semantics differ from Google's, so routes would be tuned against the wrong map.)

**Direction change (standalone app):** the Pushover notifications are no longer
needed (the owner checks ETAs on the phone), so the app will call Google's Routes
API itself instead of going through `api/`; `api/` and `web/` stay as they are
for the Pi/web workflow and are not kept in sync. Plan: Phase 4 on-device
persistence (+ hide schedules), Phase 5 Google key plumbing via a git-ignored
xcconfig (the repo is public), Phase 6 the Google client (preview polyline +
traffic-aware ETAs, ported from `api/app/google_routes_client.py`).
**Phase 4 (done):** commutes are saved to `Application Support/RoutesETA/config.json`
(same JSON shape as the API config; atomic writes; a corrupt file fails to load
visibly instead of looking empty). The schedule editor is hidden by default (the
data is kept); `-show-schedules` reveals it. Route/ETA previews are still mocks.

**Phase 5 (this PR):** the Google key comes from a git-ignored
`ios/RoutesETA/RoutesETA/Secrets.plist` (template: `ios/Secrets.example.plist`).
Deviation from the plan: not an xcconfig. A spike showed that any file in the app
folder is bundled automatically (the app target uses a synchronized folder), so a
plist needs no project-file edits, works the same in Xcode and `xcodebuild`, and a
clean clone still builds. `Platform.GoogleAPIKey` reads it and reports a helpful
error when it is missing/empty/the template value; `ios/check.sh` fails if the file
is ever tracked. 

**Phase 6 (this PR):** the app now gets real route lines and ETAs straight from
Google. `Platform.GoogleRoutesClient` ports `api/app/google_routes_client.py`
(plain REST, field masks, `via: true` intermediates, `TRAFFIC_AWARE` duration);
`GoogleRoutePreviewService` feeds the map (polyline decoded by
`Domain.PolylineCodec`, a port of `api/app/polyline.py`) and `GoogleETAService`
runs one request per route concurrently (a failing route never sinks the others;
minutes round half-to-even like Python's `round`; a missing key is reported once
up front). Errors carry actionable messages (missing key, offline, 403 key
restrictions, 429 quota) into the editor banner and ETA sheet. Verified live with
the real key: the editor draws a road-following route through the via point and
Show ETAs returned traffic-aware minutes. Tests use a `URLProtocol` stub (no
network); `GoogleLiveSmokeTests` is opt-in (see `ios/README.md`). Known gap, same
as the web builder (prd FR-9, never implemented): via points are not snapped to
the nearest road, so a point dropped off-road makes the route detour to it.

**Full-screen map (follow-up):** the inline map was too small for precise editing, so
the route editor's map has an expand button (top-right) that opens it edge to edge
with the same editing (tap the line to add a via point, drag to move, tap a handle
and Remove) and a bottom bar with the via count. Pan/zoom are shared between the
inline and full-screen copies, and both edit the same data.

## Status: Phase 1 — done (POC validated by the owner)

Re-evaluated against prd.md §12's actual exit criteria. Update: the owner
has since confirmed the Raspberry Pi deployment is working and the Phase 0
billing question (Q4) is resolved; this file simply hadn't been updated.
Remaining gaps are the smaller items listed below, plus the week of real use
(criterion 6).

| # | Success criterion (prd.md §12) | Status |
|---|---|---|
| 1 | Set up 3 routes in builder in <10 min | Likely met, never formally timed |
| 2 | Notification arrives automatically at the scheduled time, no manual step | Met — Pi deployment confirmed working by the owner |
| 3 | Changing schedule time needs only the config file + one documented command | Built and documented (`uv run python -m app.cli crontab` + the install one-liner in `api/README.md`); in use on the Pi |
| 4 | Failure notification sent instead of silence when Google is unreachable | Met — unit- and integration-tested (`pushover.format_message`'s all-failed path, `checker.check_all_routes`'s per-route independence) |
| 5 | Top-level check passes for both projects, **and the integration suite passes on both the laptop and the Raspberry Pi** | Met per the owner (laptop and Pi both working). Not re-verified from this session |
| 6 | Owner finds it useful enough to keep running for a week | Met per the owner — real Pushover notifications received as expected; some minor bugs may remain, but the POC's purpose is considered fulfilled |

The Pi deployment and billing tier were previously the blockers; both are
now resolved. Two smaller gaps from prd.md remain open:
- **FR-9** (via points snapped to the nearest road) — not implemented at
  all; the PRD marks it "best-effort," but right now it's silently absent
  rather than a documented decision.
- **prd.md §11's "Web-to-API check"** — built for `/run-now`
  (`api/tests/integration/test_run_now_api.py`), but the PRD specifically
  asks for this on `/preview` and save/read `/config` too, which was never
  added.

### Multiple commutes, each with its own routes and schedule rules (this session)

prd.md previously deferred "morning (home → work) direction and multiple
schedules" (§14). The owner asked for it now — the real commute isn't
symmetric (different routes each direction, an earlier Monday departure than
the rest of the week) — so prd.md was amended (now Draft v0.3: §2–§4, §7, §8,
§14) rather than treating this as an undocumented deviation, then
implemented full-stack:

- **Config schema** (`api/app/config_models.py`): replaced the single
  flat `origin`/`destination`/`routes`/`schedule` with `Config.commutes:
  list[Commute]`, each a `name` + its own `origin`/`destination`/`routes`
  and a `schedules: list[ScheduleRule]` (weekdays + time — a commute can
  have more than one rule, e.g. Monday-only plus Tue–Fri). New validators:
  commute names unique, route names unique within a commute (moved from the
  old top-level check), and no weekday scheduled by more than one rule
  within a commute.
- **Checker/notification/runner**: `check_commute(commute)` replaces
  `check_all_routes(config)`; `run_now(commute_name)` looks the commute up
  by name (raising `CheckerError` if it doesn't exist) and
  `pushover.format_message` gained a `label` prefix so a notification
  reads `Work to Home: Mordor 50 · City 56 · Toll Road 63`.
- **Scheduler/CLI**: `crontab_script(config)` emits one `CRON_TZ=` header
  plus one cron line per (commute, schedule rule), each invoking `run-now
  --commute '<name>'` (shell-quoted). `api/README.md` now calls out that
  renaming/deleting a commute or editing its schedule requires regenerating
  and reinstalling the crontab, since jobs refer to a commute by name.
- **JSON API**: `POST /run-now` now takes `{"commute": "..."}` in the body
  and echoes it back in the response.
- **Web builder**: new `commute-panel/` (`CommuteTabs` to switch/rename/
  add/delete commutes, `ScheduleEditor` for a commute's weekday+time rules).
  `state/routesStore.ts`'s mutators are now commute-scoped
  (`BuilderState.commutes: CommuteUI[]` + `selectedCommuteId`); `App.tsx`
  wires the selected commute's slice into the existing `MapView`/
  `RoutePanel` (both unchanged — they already took plain
  routes/origin/destination props, confirmed before touching them, so the
  only parent-side change was narrowing `MapView`'s prop type to drop the
  `BuilderState` dependency it never needed). "Send ETAs now" now targets
  the selected commute by name.
- `fixtures/sample-config.json` and `api/config.example.yaml` rewritten as
  two commutes ("Work to Home" and "Home to Work", the latter demonstrating
  the Monday-early schedule) — both test suites load the same fixture
  (prd.md §11), so the two schemas can't silently diverge.
- Full test rewrite on both sides for the new shape, plus new cases (schema
  validators, unknown-commute lookup, multi-rule cron generation, the new
  `CommuteTabs`/`ScheduleEditor` components). `api/check.sh` and `web`'s
  `npm run check` both green; no real Google/Pushover calls were made in
  this environment (no credentials available), so the integration suite
  and a live browser/dev-server check are still owed before merge.
- No migration path needed: the real `config.yaml` is gitignored and
  owner-only (recreated via the builder UI, never hand-edited), so this is
  a breaking schema change the owner re-enters through the UI.

### What's been done since slice 2 (this session)

- **Closed out Phase 0's paperwork.** `phase0/results.md` was a blank
  template despite PROGRESS.md previously calling Phase 0 "done." Filled it
  in with real evidence: Q1/Q6 yes, Q5 yes on laptop (Pi still blank — the
  same gap called out above), Q3 has two real data points including a
  notable rush-hour ETA jump. Generated fresh `.geojson` for the real
  commute routes (gitignored) so Q2's plausibility check is against the
  owner's actual roads. Q4 (billing tier) and the Pi side of Q5 are
  explicitly left for the owner — no GCP console access or Pi hardware from
  here. (Both since resolved by the owner; `phase0/results.md` may still
  need the actual answers recorded.)
- **Shared config-schema validation (prd.md §11).** New `fixtures/sample-
  config.json` at the repo root, loaded by both projects' tests (previously
  each hand-rolled its own sample config, so they could silently drift).
  `web/` gained `validateConfig()` — a hand-rolled runtime validator (no new
  dependency, matching this project's existing precedent of avoiding new
  deps — see "Route reordering is up/down buttons" below) wired into
  `getConfig()`, so a malformed `/config` response now fails clearly
  instead of silently producing broken UI state.
- **ETA display polish.** The "Send ETAs now" result was a raw Pushover-
  style string (`Sent: Constituyentes 73 · Puentes 74 · Mordor 75`) dumped
  at default `<p>` size, wrapping awkwardly. Replaced with colored chips
  (route color + name + bold minutes, `?` for a failed route) built from the
  structured `results` array `/run-now` already returns.
- **Verified the real traffic data isn't a bug.** Three routes briefly
  showed suspiciously similar ETAs (74–78 min) despite very different
  distances (12–23.5 km). Re-fetched with the full field mask and confirmed
  each via point lands within 20–70m of the actual returned path, and the
  no-traffic baselines differ sensibly (27/33/37 min) — the convergence was
  real evening-rush congestion hitting all three roads hard and roughly
  uniformly (2.1–2.8× their free-flow time), not a request bug.
- **Published to GitHub.** `main` fast-forwarded to include everything
  (Phase 0 + Phase 1 slices 1–2 + the work above), rebased onto the repo's
  initial MIT `LICENSE` commit, pushed to
  `https://github.com/juanroman/routes-eta`. Added a root `README.md` (badge
  + orientation; intentionally minimal, more to come).

## Status: Phase 1, slice 2 — done

Slice 2 = checker + Pushover notification + scheduler + the `/run-now`
endpoint and builder button (FR-11..22, FR-26). Slice 1 (route builder +
minimal backend) was already done; see below.

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
  traffic-aware ETA for all three routes, and (once `PUSHOVER_APP_TOKEN`/
  `PUSHOVER_USER_KEY` were added to `.env`) a real Pushover push confirmed
  received on the owner's phone.

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

### Repo hygiene fix

Phase 0's work existed only on `feature/phase-0-api-validation`, never merged
to `main`. Fixed by fast-forwarding `main` onto it, then branching Phase 1
from the updated `main`. Both feature branches were later fast-forward-
merged back into `main` and pushed to GitHub (see "What's been done since
slice 2" above) — `main` is now the only branch that matters.

## Not built yet / open

- **FR-9** (snap via points to nearest road) — not implemented.
- **prd.md §11's "Web-to-API check"** for `/preview` and save/read
  `/config` — only built for `/run-now` so far.
- Known minor polish item: a console a11y warning about form fields missing
  `id`/`name` attributes in `web/`.
- Success criterion 1 (setup time) was never formally timed; criterion 6
  (a week of real use) is inherently pending.

## How to pick this back up

```
cd api && uv run uvicorn app.main:app --reload   # backend
cd web && npm run dev                            # builder, separate shell
./check.sh                                       # both projects' full checks
```

Repo: `https://github.com/juanroman/routes-eta`, `main` branch, no other
branches in active use.

The Pi is deployed and running (setup steps are in `api/README.md`'s
"Checker, notification and scheduling" section). To close out Phase 1:
nothing is blocking. The owner considers the POC validated; the remaining
gaps above are optional polish, and Phase 2 (prd.md §15) would be scoped in
a separate PRD.

This doc plus the code and tests in `api/` and `web/` is the full picture —
no other plan file to track down.
