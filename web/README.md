# web/ — Route ETA builder (Phase 1, slice 1)

A React + TypeScript + Vite app for drawing named commute routes on a map.
Talks only to the local `api/` JSON API (never directly to Google — see
prd.md FR-8) via Vite's dev proxy.

## Setup

```
npm install
```

## Running

Run alongside `api/` (`uv run uvicorn app.main:app --reload` from `api/`):

```
npm run dev
```

Opens on `http://localhost:5173`. Requests to `/api/*` are proxied to the
FastAPI backend at `127.0.0.1:8000` (see `vite.config.ts`).

## Using the builder

1. Click **Set origin here** / **Set destination here**, then click the map.
2. Click **+ New route** — the route is drawn automatically between origin
   and destination.
3. Click the route line to add a via point; drag a point to move it; click a
   point and **Remove point** to delete it. Each change re-fetches the route
   from Google through `api/`.
4. Rename, recolor, reorder (↑/↓) or delete routes in the side panel.
5. **Save** writes everything to `api/config.yaml`.

## Testing

```
npm run test
```

Vitest + React Testing Library. No network and no Google key needed — the
API client is tested against mocked `fetch` responses, and route/via-point
logic is tested as pure functions independent of the map.

## One-command check

```
npm run check
```

Runs Prettier (format check), ESLint, `tsc --noEmit` (strict), Vitest, and
`npm audit`, in that order. All must pass before a PR.
