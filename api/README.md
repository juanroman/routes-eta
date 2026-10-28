# api/ — Route ETA backend (Phase 1, slice 1)

A small FastAPI app that backs the `web/` route builder. This slice covers
only what the builder needs:

- `POST /preview` — given origin, destination and via points, calls Google
  Routes API and returns the path geometry (no persistence).
- `GET /config` / `PUT /config` — read and save the routes config.

The checker, Pushover notifications and scheduler (prd.md FR-11..22) are a
later slice — not built here.

## Setup

```
uv sync
```

Requires `GOOGLE_ROUTES_API_KEY` in a `.env` file at the repo root (copy
`.env.example`). `/config` works without a key; `/preview` needs one.

## Running

```
uv run uvicorn app.main:app --reload
```

Binds to `127.0.0.1:8000` only (never `0.0.0.0`), so only the local machine
can reach it. CORS is restricted to `WEB_ORIGIN` (default
`http://localhost:5173`, Vite's dev port).

## Config files

- `config.example.yaml` — tracked, illustrative placeholder route, same shape
  as `phase0/config.yaml`. Never read by the app.
- `config.yaml` — the real config, created by `PUT /config` the first time you
  save routes in the builder. Gitignored, since it encodes your real home/work
  location.

## Testing

```
uv run pytest              # unit tests, mocked Google — no network, no key
uv run pytest -m integration   # hits the real Google Routes API (needs a key)
```

## One-command check

```
./check.sh
```

Runs black (format check), ruff (lint), mypy (strict type check), pytest
(unit), and pip-audit, in that order. All must pass before a PR.
