"""Thin client for Google's Routes API computeRoutes endpoint.

Ported from phase0/validate_api.py. fetch_route_preview() backs the builder's
preview (geometry only); fetch_route_duration() backs the checker (FR-11..13):
a traffic-aware duration, no geometry.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import requests

from app.config_models import LatLng
from app.settings import MissingApiKeyError, get_google_api_key

COMPUTE_ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
PREVIEW_FIELD_MASK = "routes.distanceMeters,routes.polyline.encodedPolyline"
DURATION_FIELD_MASK = "routes.duration"
TRAFFIC_AWARE = "TRAFFIC_AWARE"
REQUEST_TIMEOUT_S = 15


class GoogleRoutesError(Exception):
    """Raised for any failure to get a usable route back from Google."""


@dataclass
class RoutePreview:
    distance_meters: int
    encoded_polyline: str


@dataclass
class RouteDuration:
    duration_s: int


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


def _call_compute_routes(body: dict[str, Any], field_mask: str) -> dict[str, Any]:
    """POST to computeRoutes and return the first route's raw dict."""
    try:
        api_key = get_google_api_key()
    except MissingApiKeyError as exc:
        raise GoogleRoutesError(str(exc)) from exc

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": api_key,
        "X-Goog-FieldMask": field_mask,
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
        route: dict[str, Any] = response.json()["routes"][0]
        return route
    except (ValueError, KeyError, IndexError) as exc:
        raise GoogleRoutesError(f"unexpected response shape: {exc}") from exc


def fetch_route_preview(
    origin: LatLng, destination: LatLng, via: list[LatLng]
) -> RoutePreview:
    body = build_request_body(origin, destination, via)
    route = _call_compute_routes(body, PREVIEW_FIELD_MASK)

    try:
        encoded_polyline = route["polyline"]["encodedPolyline"]
        distance_meters = route["distanceMeters"]
    except KeyError as exc:
        raise GoogleRoutesError(f"unexpected response shape: {exc}") from exc

    return RoutePreview(
        distance_meters=distance_meters, encoded_polyline=encoded_polyline
    )


def fetch_route_duration(
    origin: LatLng, destination: LatLng, via: list[LatLng]
) -> RouteDuration:
    body = build_request_body(
        origin, destination, via, routing_preference=TRAFFIC_AWARE
    )
    route = _call_compute_routes(body, DURATION_FIELD_MASK)

    duration_raw = route.get("duration")
    if not isinstance(duration_raw, str) or not duration_raw.endswith("s"):
        raise GoogleRoutesError(
            f"unexpected response shape: missing or malformed 'duration' "
            f"({duration_raw!r})"
        )
    try:
        duration_s = int(duration_raw[:-1])
    except ValueError as exc:
        raise GoogleRoutesError(f"unexpected duration value: {duration_raw!r}") from exc

    return RouteDuration(duration_s=duration_s)
