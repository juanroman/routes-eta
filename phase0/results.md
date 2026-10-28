# Phase 0 results

See `prd.md` section 6 for the validation questions and exit criterion, and
`README.md` for how each answer was gathered.

**Status: filled in as far as I (Claude) can from this machine.** Three
items below are explicitly left for the owner: Q2's visual road check, Q3's
missing AM-rush data point, and Q4's billing-console lookup — none of those
can be done from a coding session. See each section's "Owner to confirm"
note.

## Run metadata

- Dates run: 2026-10-28, three runs:
  - ~12:47 CST (`20261028T184734Z`) — `phase0/validate_api.py`, illustrative
    route (Paseo de la Reforma → Ciudad Satélite)
  - ~16:4x CST — Phase 1's real `/run-now` endpoint, manual click in the
    builder UI, owner's real commute (Constituyentes/Puentes/Mordor)
  - ~17:32 CST (`20261028T233231Z`) — one-off script reusing
    `api/app/google_routes_client.py` against the same real commute, with
    the fuller field mask so `staticDuration` is captured too
- Environments tested: **laptop** (macOS, via `uv run`) — three separate
  confirmations today. **Raspberry Pi: not yet tested** (no physical access
  during this session).
- Script commit hash: `phase0/validate_api.py` as of `315528f`; the two
  newer runs used `api/app/google_routes_client.py` at the current `main`
  (Phase 1 slice 2, commit `af4d113`).

## Q1 — Via + traffic compatibility

Does a `computeRoutes` request with `via: true` intermediates *and* a
traffic-aware `routingPreference` succeed and return a duration?

- **Verdict: YES.**
- Evidence: all three runs above returned a populated `duration` field with
  `via: true` intermediates *and* `routingPreference: TRAFFIC_AWARE` in the
  same request — on the illustrative route (1 via point) and on the real
  Puentes (1 via point) and Mordor (2 via points) routes. Also exercised by
  the automated integration test
  `api/tests/integration/test_routes_api.py::test_fetch_route_duration_against_real_google_api`,
  which is the "promoted" version of this exact question.
- Surprises: none — the combination just works, no error or missing field
  at any via-point count tried (0, 1, or 2 via points).

## Q2 — Route plausibility

For each route, does the returned path visibly follow the intended roads?
(Checked by opening the generated `.geojson` files.)

**Owner to confirm** — drag these into [geojson.io](https://geojson.io) or
Google My Maps (`phase0/README.md` §4):

| Route | Source file | Looks right? | Notes |
|---|---|---|---|
| City (illustrative) | `phase0/logs/20261028T184734Z_City.geojson` | | |
| Mordor (illustrative) | `phase0/logs/20261028T184734Z_Mordor.geojson` | | |
| Toll Road (illustrative) | `phase0/logs/20261028T184734Z_Toll_Road.geojson` | | |
| Constituyentes (real) | `phase0/logs/20261028T233231Z_Constituyentes.geojson` | | |
| Puentes (real) | `phase0/logs/20261028T233231Z_Puentes.geojson` | | |
| Mordor (real) | `phase0/logs/20261028T233231Z_Mordor.geojson` | | |

The real-commute files are new — generated today specifically so this check
is against the owner's actual routes, not just the illustrative Phase 0
placeholder.

## Q3 — ETA sanity

Do ETAs differ sensibly between routes and between times of day?

| Run (time of day) | Route | Traffic-aware (min) | No-traffic baseline (min) | Notes |
|---|---|---|---|---|
| Midday (~12:47) | City (illustrative) | 45 | 34 | |
| Midday (~12:47) | Mordor (illustrative) | 51 | 39 | |
| Midday (~12:47) | Toll Road (illustrative) | 59 | 41 | |
| Late afternoon (~16:4x) | Constituyentes (real) | 47 | — (checker doesn't fetch it, FR-13) | |
| Late afternoon (~16:4x) | Puentes (real) | 47 | — | |
| Late afternoon (~16:4x) | Mordor (real) | 56 | — | |
| PM rush (~17:32) | Constituyentes (real) | 81 | 32 | +34 min vs. 45 min earlier |
| PM rush (~17:32) | Puentes (real) | 66 | 33 | +19 min vs. 45 min earlier |
| PM rush (~17:32) | Mordor (real) | 72 | 37 | +16 min vs. 56 min earlier |

**AM rush is missing entirely** — needs the owner to run `uv run python -m
app.cli run-now` (or click "Send ETAs now") some morning. Note this sends a
real Pushover push each time, so it's the owner's call when to do it.

Within what we have: traffic-aware duration is consistently well above the
no-traffic baseline (as expected), and routes rank sensibly relative to each
other. The ~45→81 min jump for Constituyentes in under an hour is the
sharpest single data point — large, but directionally consistent with
CDMX's evening rush intensifying, and arguably exactly the kind of
mid-commute degradation prd.md section 2 already calls out as a known,
accepted limitation. **Owner's judgment (acceptable / not acceptable): TBD**
— does that swing look right for Constituyentes specifically, or does it
look suspicious?

## Q4 — Billing tier and quota

**Owner to confirm** — I have no access to the Google Cloud Console from
here.

- SKU observed in Cloud Console billing report: _(Billing → Reports, filter
  by SKU — prd.md §9 lists the three Compute Routes tiers and their free
  caps)_
- Total calls made during Phase 0 + today's extra evidence-gathering: ~9
  Google Routes calls (3 illustrative + 3 real-commute full-field + 3
  checker-only duration calls from the manual `/run-now` test), plus
  whatever the `pytest -m integration` runs added (a few more, see
  `api/README.md`'s stated call budget). All trivially small.
- Projected Phase 1 monthly usage (~66 calls, prd.md §9) vs. free cap:
  comfortably under every tier's free allowance regardless of which one
  applies.
- Verdict: **not confirmed, but low risk** given the tiny volume — Phase 1
  would need months of heavy use before tier mattered.

## Q5 — Environment reachability

- **Laptop: PASS** — confirmed independently three times today, across two
  different machines' worth of routes (illustrative + real), using both the
  Phase 0 script and Phase 1's production code path.
- **Raspberry Pi: NOT TESTED.** Nothing in this repo has been run on
  physical Pi hardware yet — this is the one open item that actually blocks
  Phase 1's exit criterion (prd.md §12, success criterion 5: the integration
  suite must pass "on both the laptop and the Raspberry Pi").

## Q6 — Request shape / field mask

- Final field masks used in the shipped code (not the broader one Phase 0's
  throwaway script used): preview —
  `routes.distanceMeters,routes.polyline.encodedPolyline`
  (`api/app/google_routes_client.py:PREVIEW_FIELD_MASK`); checker —
  `routes.duration` only (`DURATION_FIELD_MASK`), deliberately narrower per
  FR-13 since the checker never needs geometry.
- Confirmation all fields returned on every successful call: yes, across
  every run today and in `api/tests/unit/test_google_routes_client.py`'s
  missing-field test cases (which confirm the failure path is also handled,
  not just the happy path).
- Verdict: **YES.**

## Exit criterion (prd.md section 6)

Q1, Q4, Q5 = yes; Q2, Q3 = owner-judged acceptable.

- Q1: yes.
- Q4: not formally confirmed (owner's GCP console check), but low-risk given volume.
- Q5: yes on laptop, **not yet tested on the Pi**.
- Q2, Q3: evidence gathered, owner's judgment calls still pending.

**GO / NO-GO: Conditional GO.** Phase 1 is already built and working
end-to-end against the real Google API and a real Pushover push (see
`PROGRESS.md`) — strictly stronger evidence than Phase 0's own script could
have produced on its own. The remaining blanks here are confirmation and
paperwork (billing console, Pi hardware, two judgment calls), not open
technical risk to the core approach.

## Notes for Phase 1

Phase 1 (route builder, checker, Pushover notification, scheduler) is
already built — see `PROGRESS.md` for what shipped and what's still open.
The only item from this file that actually blocks Phase 1's own exit
criterion is Raspberry Pi testing (Q5): FR-21 requires the checker to work
unattended on the Pi, and success criterion 5 requires the integration suite
to pass there too. Everything else here is confirmation, not a blocker.
