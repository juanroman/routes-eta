"""The checker: one traffic-aware ETA per route, independently (prd.md
FR-11..14). A failing route never prevents the others from being reported.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.config_models import Commute, NamedPoint, RouteDef
from app.google_routes_client import GoogleRoutesError, fetch_route_duration


class CheckerError(Exception):
    """Raised when a commute isn't configured completely enough to run."""


@dataclass
class RouteCheckResult:
    name: str
    # None means this route failed to fetch (FR-17: rendered as "Name ?").
    minutes: int | None
    error: str | None = None


def check_route(
    origin: NamedPoint, destination: NamedPoint, route: RouteDef
) -> RouteCheckResult:
    try:
        duration = fetch_route_duration(origin, destination, route.via)
    except GoogleRoutesError as exc:
        return RouteCheckResult(name=route.name, minutes=None, error=str(exc))
    return RouteCheckResult(name=route.name, minutes=round(duration.duration_s / 60))


def check_commute(commute: Commute) -> list[RouteCheckResult]:
    if commute.origin is None or commute.destination is None:
        raise CheckerError(
            f"commute {commute.name!r}: origin and destination must be set "
            "before checking routes"
        )
    if not commute.routes:
        raise CheckerError(f"commute {commute.name!r}: no routes are configured")

    return [
        check_route(commute.origin, commute.destination, route)
        for route in commute.routes
    ]
