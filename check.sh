#!/usr/bin/env bash
# Root-level "is everything green?" — runs both projects' one-command checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "===== api/ ====="
(cd api && ./check.sh)

echo
echo "===== web/ ====="
(cd web && npm run check)

echo
echo "All checks passed."
