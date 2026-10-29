# Route ETAs

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A small tool that fetches a traffic-aware ETA for routes you've drawn
yourself between a fixed origin and destination, and sends them in one
Pushover notification — so you can pick a route with real numbers instead of
guessing. See [`prd.md`](prd.md) for the full product requirements and
[`PROGRESS.md`](PROGRESS.md) for where the build actually is.

## Layout

- [`api/`](api/README.md) — Python/FastAPI backend: route builder JSON API,
  the ETA checker, Pushover notification, and the scheduler CLI.
- [`web/`](web/README.md) — React/TypeScript route builder (draw routes on a
  map).
- [`phase0/`](phase0/README.md) — throwaway script that validated the Google
  Routes API before any of the above was built.

## Quick start

```
cd api && uv run uvicorn app.main:app --reload   # backend
cd web && npm run dev                            # builder, separate shell
./check.sh                                       # both projects' full checks
```
