# Phase 0 — Google Routes API validation

Throwaway script that answers the six validation questions in `prd.md`
section 6, before any of Phase 1 (route builder, checker, Pushover,
scheduler) gets built. See `../prd.md` for full context.

It runs against an illustrative Mexico City route baked into `config.yaml`
(Paseo de la Reforma → Ciudad Satélite, via Periférico / Calzada Vallejo /
Viaducto Bicentenario) — not the owner's real commute. Swap in real
coordinates later if you want (see step 9 below).

## 1. One-time Google Cloud setup

1. Create or select a Google Cloud project, and link a billing account to it
   (required even for free-tier usage).
2. Enable the **Routes API** — APIs & Services → Library → search "Routes
   API" (not the legacy "Directions API").
3. Create an API key — APIs & Services → Credentials → Create Credentials →
   API key.
4. Restrict the key's API restriction to "Routes API" only. Leave the
   application restriction as "None" for Phase 0 — a laptop and a Pi don't
   share a stable IP or referrer to restrict to.

## 2. Local setup

5. At the repo root, copy `.env.example` to `.env` and fill in the key:
   ```
   GOOGLE_ROUTES_API_KEY=your-key-here
   ```
   `.env` is gitignored — never commit it.
6. Install [`uv`](https://docs.astral.sh/uv/) if you don't have it:
   ```
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
7. From `phase0/`, install the pinned dependencies:
   ```
   cd phase0
   uv sync
   ```

## 3. Running

8. Run it:
   ```
   uv run validate_api.py --env-label laptop
   ```
   This makes 6 Google API calls (3 routes × traffic-aware + non-traffic
   baseline), prints a pass/fail table, writes one `.geojson` per route to
   `logs/`, and appends a line to `logs/validate_api_log.jsonl`.

   To test from the Raspberry Pi: get the repo there (`git clone`/`pull`),
   copy `.env` over manually (it's gitignored, so `git pull` won't bring it),
   install `uv` and run `uv sync` there too, then:
   ```
   uv run validate_api.py --env-label pi
   ```

9. (Optional, later) Replace the illustrative route in `config.yaml` with
   your real work/home/via coordinates. If you do, gitignore the file at
   that point, since it would then encode a real home/work location.

## 4. Gathering evidence for all 6 questions

The script's printed verdicts cover Q1, Q5 and Q6 automatically. The rest
need a manual look:

- **Re-run 2–3 times across a day** (morning rush, midday, evening rush) to
  gather data for **Q3 (ETA sanity)**. Compare the `duration_min` values
  across entries in `logs/validate_api_log.jsonl`.
- **Q2 (plausibility)**: open the generated `logs/<timestamp>_<route>.geojson`
  files by dragging them into [geojson.io](https://geojson.io) or importing
  into Google My Maps, and confirm each path visibly follows the intended
  road (Periférico / Calzada Vallejo / Viaducto Bicentenario).
- **Q4 (billing tier & quota)**: after a few runs, check Google Cloud
  Console → Billing → Reports (filter by SKU) to see which Compute Routes
  SKU these requests billed under, and APIs & Services → Routes API →
  Quotas for the monthly cap. Billing data can lag ~15–30 minutes behind
  actual calls.

Once you have all of this, fill in `results.md` and check it against the
exit criterion in `prd.md` section 6.

## Call budget

6 calls per run (3 routes × 2 request types). A full Phase 0 campaign of a
few runs on each machine across a day (6 × 2 machines × 3 times of day ≈ 36
calls) stays trivially inside any Compute Routes free tier.
