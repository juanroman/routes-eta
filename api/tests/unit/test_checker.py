from __future__ import annotations

from typing import Any
from unittest.mock import patch

import pytest

from app.checker import CheckerError, RouteCheckResult, check_all_routes, check_route
from app.config_models import Config, NamedPoint, RouteDef
from app.google_routes_client import GoogleRoutesError, RouteDuration

ORIGIN = NamedPoint(label="Work", lat=19.4284, lng=-99.1677)
DESTINATION = NamedPoint(label="Home", lat=19.5095, lng=-99.2383)
ROUTE = RouteDef(name="City", color="#2563eb", via=[])


@patch("app.checker.fetch_route_duration", return_value=RouteDuration(duration_s=3000))
def test_check_route_success_rounds_to_nearest_minute(_mock_fetch: Any) -> None:
    result = check_route(ORIGIN, DESTINATION, ROUTE)

    assert result == RouteCheckResult(name="City", minutes=50, error=None)


@patch(
    "app.checker.fetch_route_duration",
    side_effect=GoogleRoutesError("Google Routes API returned 403"),
)
def test_check_route_failure_keeps_name_and_error(_mock_fetch: Any) -> None:
    result = check_route(ORIGIN, DESTINATION, ROUTE)

    assert result.name == "City"
    assert result.minutes is None
    assert result.error == "Google Routes API returned 403"


def test_check_all_routes_runs_each_route_independently() -> None:
    mordor = RouteDef(name="Mordor", color="#dc2626", via=[])
    config = Config(origin=ORIGIN, destination=DESTINATION, routes=[ROUTE, mordor])

    with patch("app.checker.fetch_route_duration") as mock_fetch:
        mock_fetch.side_effect = [
            RouteDuration(duration_s=3000),
            GoogleRoutesError("boom"),
        ]
        results = check_all_routes(config)

    assert [r.name for r in results] == ["City", "Mordor"]
    assert results[0].minutes == 50
    assert results[1].minutes is None
    assert results[1].error == "boom"


def test_check_all_routes_requires_origin_and_destination() -> None:
    config = Config(origin=None, destination=DESTINATION, routes=[ROUTE])

    with pytest.raises(CheckerError, match="origin and destination"):
        check_all_routes(config)


def test_check_all_routes_requires_at_least_one_route() -> None:
    config = Config(origin=ORIGIN, destination=DESTINATION, routes=[])

    with pytest.raises(CheckerError, match="no routes"):
        check_all_routes(config)
