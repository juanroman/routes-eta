"""Phase 0: validate that the Google Routes API meets the product's needs.

Answers (programmatically, where possible) the six validation questions in
prd.md section 6. Each function here is written to map cleanly onto a future
`api/` module when this script is promoted into Phase 1's integration tests:

    load_config()                    -> api/app/config.py
    build_request_body() / call_compute_routes() -> api/app/google_routes_client.py
    evaluate_results() / print_report() -> api/tests/integration/test_routes_api.py
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
import yaml
from dotenv import load_dotenv

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "config.yaml"
LOG_DIR = SCRIPT_DIR / "logs"
LOG_PATH = LOG_DIR / "validate_api_log.jsonl"

COMPUTE_ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
FIELD_MASK = "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"
REQUIRED_FIELDS = ("duration", "distanceMeters", "polyline")
REQUEST_TIMEOUT_S = 15

# One TRAFFIC_AWARE call (the critical Q1 test) plus one TRAFFIC_UNAWARE
# baseline per route, so a single run already shows whether traffic-aware
# durations differ sensibly from a traffic-blind estimate (PRD Q3).
CALL_TYPES = ("TRAFFIC_AWARE", "TRAFFIC_UNAWARE")


@dataclass
class RouteCallResult:
    route_name: str
    call_type: str
    ok: bool
    http_status: int | None = None
    duration_s: int | None = None
    distance_m: int | None = None
    polyline: str | None = None
    missing_fields: list[str] = field(default_factory=list)
    error: str | None = None

    @property
    def duration_min(self) -> float | None:
        if self.duration_s is None:
            return None
        return round(self.duration_s / 60)


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_api_key() -> str:
    load_dotenv(REPO_ROOT / ".env")
    key = os.environ.get("GOOGLE_ROUTES_API_KEY")
    if not key:
        sys.exit(
            "GOOGLE_ROUTES_API_KEY is not set. Copy .env.example to .env at the "
            "repo root and fill in a real key (see phase0/README.md)."
        )
    return key


def build_request_body(
    origin: dict[str, float],
    destination: dict[str, float],
    via_points: list[dict[str, float]],
    routing_preference: str,
) -> dict[str, Any]:
    def waypoint(point: dict[str, float], via: bool = False) -> dict[str, Any]:
        wp: dict[str, Any] = {
            "location": {
                "latLng": {"latitude": point["lat"], "longitude": point["lng"]}
            }
        }
        if via:
            wp["via"] = True
        return wp

    return {
        "origin": waypoint(origin),
        "destination": waypoint(destination),
        "intermediates": [waypoint(p, via=True) for p in via_points],
        "travelMode": "DRIVE",
        "routingPreference": routing_preference,
    }


def _single_line(text: str, max_len: int) -> str:
    collapsed = " ".join(text.split())
    return collapsed[:max_len]


def call_compute_routes(api_key: str, body: dict[str, Any]) -> requests.Response:
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": api_key,
        "X-Goog-FieldMask": FIELD_MASK,
    }
    return requests.post(
        COMPUTE_ROUTES_URL, headers=headers, json=body, timeout=REQUEST_TIMEOUT_S
    )


def run_one_call(
    api_key: str, route_name: str, call_type: str, body: dict[str, Any]
) -> RouteCallResult:
    try:
        response = call_compute_routes(api_key, body)
    except requests.RequestException as exc:
        return RouteCallResult(
            route_name=route_name, call_type=call_type, ok=False, error=str(exc)
        )

    if response.status_code != 200:
        return RouteCallResult(
            route_name=route_name,
            call_type=call_type,
            ok=False,
            http_status=response.status_code,
            error=_single_line(response.text, max_len=160),
        )

    try:
        payload = response.json()
        route = payload["routes"][0]
    except (ValueError, KeyError, IndexError) as exc:
        return RouteCallResult(
            route_name=route_name,
            call_type=call_type,
            ok=False,
            http_status=response.status_code,
            error=f"Unexpected response shape: {exc}",
        )

    missing = [f for f in REQUIRED_FIELDS if f not in route]
    duration_raw = route.get("duration")  # e.g. "1234s"
    duration_s = (
        int(duration_raw.rstrip("s")) if isinstance(duration_raw, str) else None
    )

    return RouteCallResult(
        route_name=route_name,
        call_type=call_type,
        ok=duration_s is not None,
        http_status=response.status_code,
        duration_s=duration_s,
        distance_m=route.get("distanceMeters"),
        polyline=route.get("polyline", {}).get("encodedPolyline"),
        missing_fields=missing,
    )


def decode_polyline(encoded: str) -> list[tuple[float, float]]:
    """Decode a Google encoded polyline (precision 5) into (lat, lng) pairs."""
    index, lat, lng = 0, 0, 0
    coordinates: list[tuple[float, float]] = []
    while index < len(encoded):
        for is_lng in (False, True):
            shift, result = 0, 0
            while True:
                byte = ord(encoded[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            delta = ~(result >> 1) if (result & 1) else (result >> 1)
            if is_lng:
                lng += delta
            else:
                lat += delta
        coordinates.append((lat / 1e5, lng / 1e5))
    return coordinates


def write_geojson(route_name: str, encoded_polyline: str, timestamp: str) -> Path:
    coords = decode_polyline(encoded_polyline)
    geojson = {
        "type": "Feature",
        "properties": {"route": route_name},
        "geometry": {
            "type": "LineString",
            "coordinates": [[lng, lat] for lat, lng in coords],
        },
    }
    out_path = LOG_DIR / f"{timestamp}_{route_name.replace(' ', '_')}.geojson"
    out_path.write_text(json.dumps(geojson, indent=2), encoding="utf-8")
    return out_path


def evaluate_verdicts(results: list[RouteCallResult]) -> dict[str, bool]:
    traffic_aware = [r for r in results if r.call_type == "TRAFFIC_AWARE"]
    q1_pass = bool(traffic_aware) and all(r.ok for r in traffic_aware)
    successful = [r for r in results if r.ok]
    # Vacuously-true is misleading here: with zero successful calls there's
    # nothing to check the field mask against, so that's a FAIL, not a PASS.
    q6_pass = bool(successful) and all(not r.missing_fields for r in successful)
    # Q5 just needs an HTTP response (even an error one) from every call —
    # that proves the host could reach routes.googleapis.com at all, as
    # opposed to a network-level failure (DNS/timeout/connection refused).
    q5_pass = all(r.http_status is not None for r in results)
    return {"q1_via_traffic": q1_pass, "q6_field_mask": q6_pass, "q5_reachable": q5_pass}


def print_report(
    results: list[RouteCallResult], env_label: str, verdicts: dict[str, bool]
) -> None:
    n_calls = len(results)
    print(f"Budget: {n_calls} Google API calls this run\n")

    header = (
        f"{'Route':<12} {'Call type':<16} {'Status':<8} "
        f"{'Duration (min)':<15} {'Distance (km)':<14} {'Fields OK':<10} Error"
    )
    print(header)
    print("-" * len(header))
    for r in results:
        status = "OK" if r.ok else "FAIL"
        duration = f"{r.duration_min}" if r.duration_min is not None else "-"
        distance = f"{r.distance_m / 1000:.1f}" if r.distance_m else "-"
        fields_ok = "yes" if r.ok and not r.missing_fields else "no"
        error = r.error or ""
        print(
            f"{r.route_name:<12} {r.call_type:<16} {status:<8} "
            f"{duration:<15} {distance:<14} {fields_ok:<10} {error}"
        )

    print()
    print(f"Q1 (via + traffic-aware):     {'PASS' if verdicts['q1_via_traffic'] else 'FAIL'}")
    print(f"Q5 (reachability from {env_label}): {'PASS' if verdicts['q5_reachable'] else 'FAIL'}")
    print(f"Q6 (field mask completeness): {'PASS' if verdicts['q6_field_mask'] else 'FAIL'}")
    print("Q2 (plausibility):             MANUAL — see phase0/logs/*.geojson (drag into geojson.io)")
    print("Q3 (ETA sanity across times):  MANUAL — compare entries in phase0/logs/validate_api_log.jsonl")
    print("Q4 (billing tier/quota):       MANUAL — check Cloud Console > Billing > Reports (wait ~15-30min)")


def append_log(entry: dict[str, Any]) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--env-label",
        default=platform.node() or "unknown",
        help="Label for this environment (e.g. laptop, pi) — set explicitly so "
        "Q5 reachability evidence in the log is unambiguous.",
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    args = parser.parse_args()

    api_key = load_api_key()
    config = load_config(args.config)
    origin = config["origin"]
    destination = config["destination"]
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    results: list[RouteCallResult] = []
    for route in config["routes"]:
        for call_type in CALL_TYPES:
            body = build_request_body(origin, destination, route["via"], call_type)
            results.append(run_one_call(api_key, route["name"], call_type, body))
            time.sleep(0.2)  # be polite between calls

        traffic_result = next(
            r
            for r in results
            if r.route_name == route["name"] and r.call_type == "TRAFFIC_AWARE"
        )
        if traffic_result.ok and traffic_result.polyline:
            write_geojson(route["name"], traffic_result.polyline, timestamp)

    verdicts = evaluate_verdicts(results)
    print_report(results, args.env_label, verdicts)

    append_log(
        {
            "timestamp": timestamp,
            "env_label": args.env_label,
            "verdicts": verdicts,
            "results": [
                {
                    "route": r.route_name,
                    "call_type": r.call_type,
                    "ok": r.ok,
                    "duration_min": r.duration_min,
                    "distance_m": r.distance_m,
                    "error": r.error,
                }
                for r in results
            ],
        }
    )

    return 0 if verdicts["q1_via_traffic"] and verdicts["q6_field_mask"] else 1


if __name__ == "__main__":
    sys.exit(main())
