"""Thin client for Google's Routes API computeRoutes endpoint.

Ported from phase0/validate_api.py. This slice only needs route geometry for
the builder's preview (no traffic-aware duration), but build_request_body()
keeps the routing_preference parameter so the future checker can reuse it
unchanged with TRAFFIC_AWARE and a duration-including field mask.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import requests

from app.config_models import LatLng
from app.settings import MissingApiKeyError, get_google_api_key

COMPUTE_ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
PREVIEW_FIELD_MASK = "routes.distanceMeters,routes.polyline.encodedPolyline"
REQUEST_TIMEOUT_S = 15


class GoogleRoutesError(Exception):
    """Raised for any failure to get a usable route back from Google."""


@dataclass
class RoutePreview:
    distance_meters: int
    encoded_polyline: str


def _waypoint(point: LatLng, via: bool = False) -> dict[str, Any]:
    wp: dict[str, Any] = {
        "location": {"latLng": {"latitude": point.lat, "longitude": point.lng}}
    }
    if via:
        wp["via"] = True
    return wp


def build_request_body(
    origin: LatLng,
    destination: LatLng,
    via: list[LatLng],
    routing_preference: str | None = None,
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "origin": _waypoint(origin),
        "destination": _waypoint(destination),
        "intermediates": [_waypoint(p, via=True) for p in via],
        "travelMode": "DRIVE",
    }
    if routing_preference is not None:
        body["routingPreference"] = routing_preference
    return body


def fetch_route_preview(
    origin: LatLng, destination: LatLng, via: list[LatLng]
) -> RoutePreview:
    try:
        api_key = get_google_api_key()
    except MissingApiKeyError as exc:
        raise GoogleRoutesError(str(exc)) from exc

    body = build_request_body(origin, destination, via)
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": api_key,
        "X-Goog-FieldMask": PREVIEW_FIELD_MASK,
    }

    try:
        response = requests.post(
            COMPUTE_ROUTES_URL, headers=headers, json=body, timeout=REQUEST_TIMEOUT_S
        )
    except requests.RequestException as exc:
        raise GoogleRoutesError(f"could not reach Google Routes API: {exc}") from exc

    if response.status_code != 200:
        text = " ".join(response.text.split())[:160]
        raise GoogleRoutesError(
            f"Google Routes API returned {response.status_code}: {text}"
        )

    try:
        route = response.json()["routes"][0]
        encoded_polyline = route["polyline"]["encodedPolyline"]
        distance_meters = route["distanceMeters"]
    except (ValueError, KeyError, IndexError) as exc:
        raise GoogleRoutesError(f"unexpected response shape: {exc}") from exc

    return RoutePreview(
        distance_meters=distance_meters, encoded_polyline=encoded_polyline
    )
