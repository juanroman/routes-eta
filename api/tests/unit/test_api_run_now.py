from __future__ import annotations

from typing import Any
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.checker import CheckerError, RouteCheckResult
from app.pushover import PushoverError
from app.runner import RunResult


@patch("app.routers.run_now.run_now")
def test_run_now_success(mock_run_now: Any, client: TestClient) -> None:
    mock_run_now.return_value = RunResult(
        commute="Work to Home",
        message="Work to Home: City 56 · Mordor ?",
        results=[
            RouteCheckResult(name="City", minutes=56),
            RouteCheckResult(name="Mordor", minutes=None, error="timeout"),
        ],
    )

    response = client.post("/run-now", json={"commute": "Work to Home"})

    assert response.status_code == 200
    body = response.json()
    assert body["commute"] == "Work to Home"
    assert body["message"] == "Work to Home: City 56 · Mordor ?"
    assert body["results"] == [
        {"name": "City", "minutes": 56, "error": None},
        {"name": "Mordor", "minutes": None, "error": "timeout"},
    ]
    mock_run_now.assert_called_once_with("Work to Home")


@patch("app.routers.run_now.run_now", side_effect=CheckerError("no routes configured"))
def test_run_now_checker_error_returns_400(
    _mock_run_now: Any, client: TestClient
) -> None:
    response = client.post("/run-now", json={"commute": "Work to Home"})

    assert response.status_code == 400
    assert "no routes configured" in response.json()["detail"]


@patch("app.routers.run_now.run_now", side_effect=PushoverError("send failed"))
def test_run_now_pushover_error_returns_502(
    _mock_run_now: Any, client: TestClient
) -> None:
    response = client.post("/run-now", json={"commute": "Work to Home"})

    assert response.status_code == 502
    assert "send failed" in response.json()["detail"]


def test_run_now_requires_commute_in_body(client: TestClient) -> None:
    response = client.post("/run-now", json={})

    assert response.status_code == 422
