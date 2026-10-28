# PRD: Commute Route ETAs (working title)

| | |
|---|---|
| **Status** | Draft v0.2 (split into `api/` Python project and `web/` React project, one repository) |
| **Date** | 2026-10-28 |
| **Owner** | Juan |
| **Audience** | The builder (Claude Code session) and the owner |

---

## 1. Summary

A small tool that takes **routes the user has defined themselves** between two fixed places, asks a traffic-aware routing service how long each route will take right now, and sends a push notification with the numbers:

```
Mordor 50 · City 56 · Toll Road 63
```

The tool never chooses a route. It gives the driver honest, comparable ETAs for routes the driver already knows, so the driver can weigh time against everything the tool cannot see (stress, road quality, safety, personal rules).

Work is split into three phases:

- **Phase 0 – API validation.** Prove the data we need can be obtained before building anything.
- **Phase 1 – POC.** Two projects in one repository: a **Python** project (`api/`: JSON API + scheduled checker that sends a Pushover notification) and a **React** project (`web/`: the route builder). The builder runs on a laptop; the checker runs on a laptop and on a Raspberry Pi.
- **Phase 2 – Apple ecosystem.** A real backend, an iPhone app, an Apple Watch app and Siri. Out of scope for this document beyond a short outline (section 15).

## 2. Problem and motivation

- The owner drives a Tesla in Mexico City. The car and Apple Maps recommend the *fastest* route every time. The owner does not trust the car's traffic data, and finds Waze more accurate in Mexico City (it was used daily with CarPlay).
- The owner has three very different routes from work to home (for example: through the city via Constituyentes + Viaducto; a shortcut the owner calls "Mordor" via Vasco de Quiroga + Eje 6; and a toll road). A navigator that only says "Mordor is 5 minutes faster" is the wrong tool: Mordor is only worth it in an emergency, and the toll road is the smoothest ride even when it is slower.
- The valuable thing is **empowering the driver with ETAs for chosen routes**, not recommending one.
- Waze has no public API for live routing or alerts (see Appendix A), so the tool must use a different traffic-aware provider.

### Known limitation, accepted for the POC

An ETA is a snapshot of traffic *now*. A route can degrade while the driver is on it (a past incident: the toll road looked fine at departure and was jammed 20 minutes later). Trends, history and mid-drive alerts would help, but are deferred (section 14).

## 3. Users and scenarios

**User:** one person (the owner), with one commute. Designed so another user could configure their own routes.

**Primary scenario:** At a configured time on weekdays, the owner's phone buzzes with a notification listing each route and its ETA. At a glance the owner picks a route.

**Secondary scenario:** On a laptop, the owner opens a local page, draws the routes once by dragging on a map, and saves them.

## 4. Goals and non-goals

### Goals (POC)
1. Let the owner define any number of named routes between a fixed origin and destination by clicking and dragging on a map.
2. At a scheduled time on weekdays, fetch a traffic-aware ETA for each route and send one Pushover notification.
3. Run locally on a laptop and unattended on a Raspberry Pi.
4. Establish production-grade engineering hygiene from day one (tests, typing, linting, dependency audit).

### Non-goals (POC)
- Turn-by-turn navigation.
- Recommending or auto-selecting a route.
- Showing tolls, costs, distances or other route details the driver already knows.
- Route-drift detection (checking that the returned path matches the drawn path).
- History, trends, or "usual ETA" comparisons.
- Validating Google's accuracy against Waze.
- Home-bound morning direction (the POC covers **work → home only**; see section 7).
- Any native app, backend service or Watch/Siri integration (Phase 2).
- Scraping or calling any unofficial Waze endpoint (see Appendix A).

## 5. Phases and exit criteria

| Phase | Deliverable | Exit criterion |
|---|---|---|
| **0 – API validation** | A throwaway script + pass/fail checklist run against the owner's real routes and key | All validation questions in section 6 answered "yes", or a documented decision to change provider |
| **1 – POC** | Route builder, checker, Pushover notification, scheduler, engineering standards | Success criteria in section 12 met |
| **2 – Apple app + backend** | See section 15 | Defined in a separate PRD |

**Phase 1 must not start until Phase 0 passes.** A failed Phase 0 is a valid, useful outcome: it sends us to an alternative provider (TomTom, HERE, Mapbox) before more effort is spent.

## 6. Phase 0 – API validation

### Purpose
Ensure the Google Routes API returns the data the product depends on, for the owner's real routes, before building Phase 1.

### Prerequisites
- A Google Cloud project with the **Routes API** enabled and billing configured.
- An API key stored in a local `.env` file (never committed).
- The owner's real work and home locations, and 1–3 via points per route.

### Validation questions
1. **Via + traffic compatibility.** Does a `computeRoutes` request with `via: true` intermediate waypoints *and* a traffic-aware `routingPreference` succeed and return a duration? (Google's reference does not list this combination as unsupported, but it is not explicitly confirmed. This is the single most important question.)
2. **Route plausibility.** For each of the owner's routes, does the returned path visibly follow the intended roads? (Manual check against a map. This is not the automated drift check, which is out of scope.)
3. **ETA sanity.** Do the returned ETAs differ sensibly between routes and between times of day (for example, rush hour vs. midday)?
4. **Billing tier and quota.** Which Compute Routes SKU tier do these requests bill under, and does the free monthly allowance cover the planned schedule? (Google's pricing page does not state what triggers each tier.)
5. **Environment reachability.** Can the key be used from the owner's laptop *and* from the Raspberry Pi?
6. **Request shape.** Which fields must the response field mask include to get what the notification needs (duration at minimum)?

### Deliverable
- A small script, `validate_api` (name flexible), that runs the calls and prints a pass/fail table.
- A short results note recording the answers and any surprises.
- This script is **promoted to the first integration test** in Phase 1 (section 11).

### Exit criterion
Questions 1, 4 and 5 are "yes" and 2 and 3 are judged acceptable by the owner. Otherwise: stop, record findings, evaluate an alternative provider.

## 7. Phase 1 – Functional requirements

Direction for the POC is **work → home**. The config holds one origin and one destination, so swapping them later (or adding a second config) needs no code change.

### 7.1 Route builder (`web/` project: React app)

- **FR-1.** A React web app (the `web/` project, run locally) shows a map with the configured origin and destination. It talks only to the Python JSON API (section 7.5), never directly to Google.
- **FR-2.** The owner can create a route: an initial route between origin and destination is drawn automatically.
- **FR-3.** The owner can add a via point by clicking/pressing the route line, and move it by dragging. On release, the route is recalculated through the via points and redrawn.
- **FR-4.** Via points can be removed.
- **FR-5.** Each route has a **name** chosen by the owner and a distinguishing color.
- **FR-6.** The owner can create, rename, delete and reorder routes. Any number of routes is supported.
- **FR-7.** Saving writes the routes to the config file (section 8). The saved definition is: name + ordered list of via points (latitude/longitude).
- **FR-8.** The Google API key is held only by the Python API (`api/`). It is never sent to, or bundled into, the browser app.
- **FR-9.** Via points are snapped to the nearest road where the API supports it, so a point does not land on the wrong carriageway of a divided avenue. (Best-effort; verify in Phase 0/1.)
- **FR-10.** Touch-friendly handles (large hit targets), since the page may be used on a phone or tablet.

### 7.2 Checker

- **FR-11.** For each saved route, the checker issues one traffic-aware `computeRoutes` request (origin → via points → destination, driving mode) departing "now".
- **FR-12.** The checker extracts the route duration and converts it to whole minutes (rounding rule to be fixed in implementation; rounding to nearest minute is the default).
- **FR-13.** Requests use a response field mask limited to the fields actually needed.
- **FR-14.** Routes are requested independently, so one failing route does not prevent the others from being reported.

### 7.3 Notification

- **FR-15.** One Pushover notification is sent per run.
- **FR-16.** The message lists every route by name with its ETA in minutes, in the **order defined in the config** (default; see open questions), separated by ` · `.
  Example: `Mordor 50 · City 56 · Toll Road 63`
- **FR-17.** If an individual route fails, it appears as `Name ?` and the other routes are still shown.
- **FR-18.** If *no* route can be fetched (for example, Google unreachable), send a short failure notification, for example `Couldn't fetch ETAs`, so silence never makes the owner wonder whether the tool is working.
- **FR-19.** Pushover token and user key come from environment configuration, never from the config file in version control.

### 7.4 Scheduling

- **FR-20.** The checker runs on **weekdays (Mon–Fri)** at a **single time of day configured in the config file**, interpreted in a configured timezone (default `America/Mexico_City`).
- **FR-21.** Changing the time requires editing only the config file, plus at most one documented command (for example, regenerating the cron entry). The implementation may use cron or a built-in scheduler; it must work unattended on a Raspberry Pi.
- **FR-22.** A manual "run now" command sends the notification immediately, ignoring the schedule, for testing.

### 7.5 JSON API between `web/` and `api/`

The Python project exposes a small local HTTP JSON API for the builder. Endpoint names and payloads are an implementation detail, but the capabilities are required:

- **FR-23.** *Compute a route preview:* given origin, destination and an ordered list of via points, return the drawn path (and its ETA, optionally) so the builder can render it. This calls Google on the builder's behalf, using the server-held key.
- **FR-24.** *Read config:* return the current saved routes, origin, destination and schedule.
- **FR-25.** *Save config:* validate and write the routes (and schedule) to the config file. Invalid input returns a clear error and does not corrupt the file.
- **FR-26.** *Run now:* trigger the checker immediately (the same behavior as FR-22), so the builder can offer a "send me the ETAs now" button.
- **FR-27.** The API listens on localhost only by default. Cross-origin access is limited to the local web app's origin.
- **FR-28.** The API is **not** required to run on the Raspberry Pi. Only the checker is.

## 8. Data model and configuration

### Routes and schedule config (illustrative; format YAML or JSON at the builder's discretion)

```yaml
timezone: America/Mexico_City
schedule:
  weekdays: [mon, tue, wed, thu, fri]
  time: "18:30"          # HH:MM local time
origin:
  label: Work
  lat: 19.0000
  lng: -99.0000
destination:
  label: Home
  lat: 19.0000
  lng: -99.0000
routes:
  - name: City
    via:
      - { lat: 19.0000, lng: -99.0000 }
  - name: Mordor
    via:
      - { lat: 19.0000, lng: -99.0000 }
  - name: Toll Road
    via:
      - { lat: 19.0000, lng: -99.0000 }
```

(Coordinates are placeholders.)

### Config is the contract and the handoff

- The config file is the **only contract** between the two projects and between the laptop and the Pi: the builder (via the API) writes it, the checker reads it. Its schema is defined once (for example a JSON Schema or a typed model) and validated on both the Python and TypeScript sides, so they cannot drift apart.
- Because the builder runs on the laptop and the checker runs on the Pi, the saved config must reach the Pi. The POC supports **copying the file** (for example with `scp`) or **pulling it from a private repository**; the chosen method is documented in the README. No automatic sync is built in Phase 1.
- Secrets are never part of the config file.

### Secrets (`.env`, git-ignored; repository ships `.env.example`)

```
GOOGLE_ROUTES_API_KEY=
PUSHOVER_APP_TOKEN=
PUSHOVER_USER_KEY=
```

## 9. External services

### Google Routes API
- Endpoint: `POST https://routes.googleapis.com/directions/v2:computeRoutes`.
- A response field mask is **required** (header `X-Goog-FieldMask`, comma-separated, no spaces). Google advises against `*` and top-level masks.
- API key passed in the `X-Goog-Api-Key` header.
- `intermediates`: up to 25 waypoints; `via` waypoints pass through without stopping.
- `routingPreference` (traffic-aware options) is allowed only with driving mode. `departureTime` defaults to the request time.
- Alternative routes are not returned when intermediates are present (acceptable; routes are user-defined).
- **Python client:** Google publishes `google-maps-routing` (`from google.maps import routing_v2`), but it is built around Application Default Credentials and its sample is marked as a template. **Decision: use plain REST with `requests`** for simplicity.

### Pricing and quota
- Compute Routes SKUs and monthly free caps (from Google's pricing page at the time of writing): Essentials 10,000 free ($5.00 per 1,000 after); Pro 5,000 free ($10.00); Enterprise 1,000 free ($15.00).
- Which tier traffic-aware + via requests bill under is **not stated** on the page and is a Phase 0 question.
- **Expected usage:** `routes × weekdays` per month. With 3 routes on ~22 weekdays that is about 66 requests per month, far below every free cap, even if the builder adds a few hundred calls during setup. The PRD requires the integration test suite to stay within a small stated call budget (section 11).

### Pushover
- Simple authenticated HTTPS POST. Needs an application token and a user key.

### Map for the route builder
- Use an open-source browser map library with a tile source suitable for personal use (default proposal: `react-leaflet` with OpenStreetMap tiles; the builder must respect the tile provider's usage policy). Only routing calls go to Google, and they go through the Python API.
- The exact library and tile provider are an implementation decision (open question).

## 10. Architecture and stack

```
 LAPTOP
   web/  React app (route builder)
        │  HTTP JSON (localhost)
        ▼
   api/  Python JSON API ──► Google Routes API
        │ reads/writes
        ▼
   config file (routes, schedule)  ── copied / pulled ──┐
                                                         ▼
 RASPBERRY PI (or laptop)
   config file ──► api/ checker (scheduled) ──► Google Routes API
                              │
                              └──► Pushover API
```

One repository, two projects:

```
/api   Python: core logic, JSON API, checker, tests
/web   React + TypeScript: route builder, tests
```

- **`api/` language:** Python (version fixed at implementation; must be available on the Raspberry Pi). `requests` for outbound calls. The JSON API uses a small framework (FastAPI or Flask, implementer's choice).
- **`web/` stack:** React + TypeScript, built with Vite, map via `react-leaflet`. Talks only to the local JSON API (in development, Vite's dev proxy can forward `/api` calls to avoid cross-origin setup).
- **Runtime:** `api/` uses a virtual environment with pinned dependencies. `web/` uses a lockfile (npm). The Pi needs **only** the Python checker, not Node.
- **Structure:** in `api/`, keep Google access, config handling, message formatting and scheduling in separate modules so the Phase 2 backend can reuse the same core logic. In `web/`, keep the API client separate from the map UI components.

## 11. Engineering standards and testing

### Required tooling – `api/` (Python)
| Tool | Purpose |
|---|---|
| **pytest** | Unit and integration tests |
| **black** | Code formatting (owns formatting) |
| **ruff** | Linting (owns lint rules; configured so it does not conflict with black) |
| **mypy** | Static type checking, strict settings on project code |
| **pip-audit** | Dependency vulnerability scanning against the pinned requirements |

- All tool configuration lives in `pyproject.toml`.
- **One command** (script or Makefile target) runs formatting check, lint, type check, unit tests and pip-audit. A pre-commit hook is recommended.
- Dependencies are pinned. Secrets are never committed. `.env.example` documents required variables.

### Required tooling – `web/` (React + TypeScript)
| Tool | Purpose |
|---|---|
| **TypeScript** (strict) | Type checking (`tsc --noEmit`) |
| **ESLint** | Linting |
| **Prettier** | Formatting (owns formatting; ESLint configured not to conflict) |
| **Vitest** (+ React Testing Library) | Unit/component tests |
| **npm audit** | Dependency vulnerability scanning |

- The lockfile is committed; dependencies are pinned through it.
- **One command** (npm script) runs format check, lint, type check, tests and audit.
- A **top-level command** at the repository root runs both projects' checks, so "is everything green?" is one step.
- The config schema (section 8) is validated by both `api/` and `web/`; tests on each side use the same sample config fixtures so the two cannot silently diverge.

### Unit tests – `web/`
- The API client is tested against mocked JSON API responses.
- Components that build and edit routes (add/move/remove a via point, rename, reorder, save) are tested without a real map or network.
- No Google key is ever needed to run `web/` tests.

### Unit tests – `api/`
- Google and Pushover are **mocked** using realistic saved responses.
- Cover: config loading and validation, request building (origin, via points, field mask, traffic-aware preference), ETA parsing and minute rounding, notification formatting (order, `?` for failed routes, total-failure message), and weekday/time schedule logic.
- Fast, no network, no key required. Run on every change.

### Integration tests (`api/`)
- Call the **real** Google Routes API with the owner's real routes and key. Mocks only prove agreement with our assumptions; integration tests check whether the assumptions are true.
- Assert on **shape and sanity, not exact values** (traffic changes constantly): response received, positive duration, requested fields present, ETA within a plausible range.
- Include the contract checks from Phase 0 (via + traffic-aware). The Phase 0 validation script becomes the first integration test.
- A separate, clearly labeled Pushover integration test sends one real notification; use sparingly.
- Marked with a pytest marker (`integration`). Plain `pytest` skips them; `pytest -m integration` runs them. With no key set they skip with a clear message rather than failing confusingly.
- **Call budget:** the suite makes only a handful of API calls per run, stated explicitly in the repo, so it never threatens the free monthly allowance.
- **When they run:** before any release; after deploying to the Raspberry Pi (as a smoke test of the real environment); optionally weekly to catch Google-side changes early.
- **Web-to-API check:** one integration-style test starts the real Python API (with its real Google key) and exercises the route-preview and save/read endpoints end to end, so a mismatch between `web/` and `api/` surfaces before release rather than at the map.

## 12. Success criteria (Phase 1)

1. Setting up three routes from scratch in the builder takes under 10 minutes.
2. At the configured weekday time, a notification with one ETA per route arrives on the owner's phone without any manual step.
3. Changing the schedule time requires only the config file (plus at most the one documented command).
4. When Google is unreachable, a failure notification is sent instead of silence.
5. The top-level check command passes for both projects (format, lint, types, unit tests, audit), and the `api/` integration suite passes against the real APIs on both the laptop and the Raspberry Pi.
6. The owner finds the ETAs useful enough to keep the tool running for a week (subjective, owner-judged; formal accuracy validation against Waze is out of scope).

## 13. Risks and assumptions

| Risk / assumption | Impact | Mitigation |
|---|---|---|
| Via waypoints may not combine with traffic-aware routing as hoped | Core idea fails | Phase 0 question 1; fallback provider |
| Google's Mexico City traffic may be less accurate than Waze's | Numbers less trusted | Accepted for POC; revisit with another provider if the owner distrusts the numbers |
| Between via points, the engine may reroute around congestion, so an ETA may describe a different road than intended | Misleading ETA | Accepted in POC (drift check deferred); mitigated by placing enough via points; Phase 0 manual plausibility check |
| ETA is a snapshot; traffic may worsen en route | Wrong decision at departure | Documented limitation; trends and mid-drive alerts deferred |
| Which billing tier applies is unknown | Unexpected cost | Phase 0 question 4; expected volume is tiny |
| Via points land on the wrong side of a divided road | Detour | Snap to nearest road; manual verification |
| API or pricing changes | Breakage | Integration tests; weekly run |
| Home network / Pi cannot reach Google | Silent failure | Failure notification (FR-18); reachability checked in Phase 0 |

## 14. Deferred beyond the POC

- History log, trend arrows and a "usual ETA" comparison.
- Automated route-drift detection.
- Validation of ETA accuracy against Waze or against actual drive times.
- Mid-drive alerts when the chosen route degrades.
- Morning (home → work) direction and multiple schedules.
- Fastest-first ordering (default is config order; see open questions).

## 15. Phase 2 outline (for context only; separate PRD)

- A real backend that holds the API key, caches results, stores route definitions and sends push notifications at the scheduled time (an iOS local notification cannot fetch data at delivery time, so server-side push is needed for live ETAs).
- An iPhone app: set addresses, draw routes, schedule the notification.
- An Apple Watch app showing the ETAs at a glance (complications refresh within platform limits, so "last updated" semantics apply).
- Siri via App Intents ("which route?"), to be verified on a real device.
- A web page for the Tesla browser using the same backend; the React app from Phase 1 is a natural starting point.
- Phase 1's core logic (config, API access, formatting) is structured so it can be reused or ported.
- Re-evaluate the routing provider (Google vs. TomTom/HERE vs. Apple MapKit) using the history and validation data deferred from Phase 1.

## 16. Open questions and proposed defaults

| Question | Proposed default |
|---|---|
| Order of routes in the notification | Config order (fixed), so the owner learns where each route sits |
| Failure notification wording | Short `Couldn't fetch ETAs` message (FR-18) |
| Python version | Newest version available on the Raspberry Pi |
| Repository layout | One repository, `api/` (Python) and `web/` (React + TypeScript) |
| Builder map library / tile provider | `react-leaflet` + OpenStreetMap, respecting tile policy |
| Python API framework | FastAPI or Flask (implementer's choice) |
| Web build tool | Vite |
| Config handoff laptop → Pi | Copy the file (`scp`) or pull from a private repo; no automatic sync in Phase 1 |
| Scheduler mechanism | cron entry generated from the config |
| Pushover priority and sound | Normal priority, default sound |
| Minute rounding | Nearest minute |
| Config format | YAML |

## Appendix A – Research notes: Waze

- **TeslaNav** (teslanav.com, repo `R44VC0RP/teslanav.com`, PolyForm Noncommercial license) is a navigation web app for Tesla's browser. Its Waze alerts come from the **unofficial** Live Map endpoint `https://www.waze.com/live-map/api/georss`, proxied through a server route with a Redis cache and rate limiting. No key or partnership is involved. Routing in TeslaNav comes from Mapbox, not Waze.
- Waze's **official** developer surface is: Deep Links (open Waze from a link), iFrame (embed the Live Map, no alerts or routing data), Transport SDK (partner-gated), Waze for Cities / Data Feeds (for governments and road operators), and Audio Kit (partners).
- Waze's Terms of Use, as summarized, prohibit automated access to content, building databases from it, commercial use without permission, and integrating the service into other products without written consent. The unofficial endpoint has also been reported to return HTTP 403 to datacenter IPs.
- **Conclusion:** there is no sanctioned way to get Waze's own ETAs for this use case, which is why this project uses a different traffic-aware provider.

### Sources
- [teslanav.com](https://teslanav.com)
- [R44VC0RP/teslanav.com](https://github.com/R44VC0RP/teslanav.com)
- [Waze developer products](https://developers.google.com/waze)
- [Using the Waze iFrame](https://developers.google.com/waze/iframe)
- [Waze Transport SDK](https://developers.google.com/waze/intro-transport)
- [Waze Terms of Use](https://support.google.com/waze/answer/12373727?hl=en)
- [Waze for Cities](https://waze.com/wiki/USA/Waze_for_Cities)
- [Routes API client libraries](https://developers.google.com/maps/documentation/routes/client-libraries)
- [computeRoutes reference](https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRoutes)
- [Google Maps Platform pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
