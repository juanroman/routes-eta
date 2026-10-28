# Phase 0 results

Fill this in after running `validate_api.py` on both the laptop and the
Raspberry Pi, across a few times of day. See `prd.md` section 6 for the
validation questions and exit criterion, and `README.md` for how to gather
each answer.

## Run metadata

- Dates run:
- Environments tested: laptop (model/OS: ), Pi (model/OS: )
- Script commit hash:

## Q1 — Via + traffic compatibility

Does a `computeRoutes` request with `via: true` intermediates *and* a
traffic-aware `routingPreference` succeed and return a duration?

- Verdict:
- Evidence (script output summary):
- Surprises:

## Q2 — Route plausibility

For each route, does the returned path visibly follow the intended roads?
(Checked by opening the generated `.geojson` files.)

| Route | Looks right? | Notes |
|---|---|---|
| City | | |
| Mordor | | |
| Toll Road | | |

## Q3 — ETA sanity

Do ETAs differ sensibly between routes and between times of day?

| Run (time of day) | City (min) | Mordor (min) | Toll Road (min) | Notes |
|---|---|---|---|---|
| AM rush | | | | |
| Midday | | | | |
| PM rush | | | | |

Owner's judgment (acceptable / not acceptable):

## Q4 — Billing tier and quota

- SKU observed in Cloud Console billing report:
- Total calls made during Phase 0 testing:
- Projected Phase 1 monthly usage (~66 calls) vs. free cap:
- Verdict:

## Q5 — Environment reachability

- Laptop: pass / fail —
- Raspberry Pi: pass / fail —

## Q6 — Request shape / field mask

- Final field mask used: `routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline`
- Confirmation all fields returned on every successful call:
- Verdict:

## Exit criterion (prd.md section 6)

Q1, Q4, Q5 = yes; Q2, Q3 = owner-judged acceptable.

**GO / NO-GO:**

## Notes for Phase 1

