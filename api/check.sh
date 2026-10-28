#!/usr/bin/env bash
# One command: format check, lint, type check, unit tests, dependency audit.
set -euo pipefail
cd "$(dirname "$0")"

echo "== black =="
uv run black --check .

echo "== ruff =="
uv run ruff check .

echo "== mypy =="
uv run mypy app

echo "== pytest (unit) =="
uv run pytest

echo "== pip-audit =="
uv run pip-audit

echo "All checks passed."
