"""Hits the real Google Routes API. Run with: uv run pytest -m integration

Skips cleanly if GOOGLE_ROUTES_API_KEY isn't set. Makes 1 call per test.
"""

from __future__ import annotations

import os

import pytest
from dotenv import load_dotenv

from app.config_models import LatLng
from app.google_routes_client import fetch_route_duration, fetch_route_preview
from app.settings import REPO_ROOT

load_dotenv(REPO_ROOT / ".env")

pytestmark = pytest.mark.integration

ORIGIN = LatLng(lat=19.4284, lng=-99.1677)
DESTINATION = LatLng(lat=19.5095, lng=-99.2383)
VIA = [LatLng(lat=19.4550, lng=-99.2050)]


@pytest.mark.skipif(
    not os.environ.get("GOOGLE_ROUTES_API_KEY"),
    reason="GOOGLE_ROUTES_API_KEY not set — copy .env.example to .env to run this",
)
def test_fetch_route_preview_against_real_google_api() -> None:
    result = fetch_route_preview(ORIGIN, DESTINATION, VIA)

    assert result.distance_meters > 0
    assert len(result.encoded_polyline) > 0


@pytest.mark.skipif(
    not os.environ.get("GOOGLE_ROUTES_API_KEY"),
    reason="GOOGLE_ROUTES_API_KEY not set — copy .env.example to .env to run this",
)
def test_fetch_route_duration_against_real_google_api() -> None:
    """Promotes Phase 0 question 1: via waypoints + TRAFFIC_AWARE together.

    This is the combination Google's reference doesn't explicitly confirm —
    the slice-1 preview test above never sets routingPreference at all, so
    this is the only place it's actually exercised against the real API.
    """
    result = fetch_route_duration(ORIGIN, DESTINATION, VIA)

    assert result.duration_s > 0
