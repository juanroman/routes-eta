from __future__ import annotations

from typing import Any
from unittest.mock import patch

import pytest
import requests

from app.checker import RouteCheckResult
from app.pushover import (
    FAILURE_MESSAGE,
    PushoverError,
    format_message,
    send_notification,
)
from app.settings import MissingPushoverCredentialsError


def test_format_message_joins_in_order() -> None:
    results = [
        RouteCheckResult(name="City", minutes=56),
        RouteCheckResult(name="Mordor", minutes=50),
        RouteCheckResult(name="Toll Road", minutes=63),
    ]

    assert format_message(results) == "City 56 · Mordor 50 · Toll Road 63"


def test_format_message_shows_question_mark_for_failed_route() -> None:
    results = [
        RouteCheckResult(name="City", minutes=56),
        RouteCheckResult(name="Mordor", minutes=None, error="timeout"),
    ]

    assert format_message(results) == "City 56 · Mordor ?"


def test_format_message_all_failed_is_short_failure_message() -> None:
    results = [
        RouteCheckResult(name="City", minutes=None, error="boom"),
        RouteCheckResult(name="Mordor", minutes=None, error="boom"),
    ]

    assert format_message(results) == FAILURE_MESSAGE


def test_format_message_with_label_prefixes_the_commute_name() -> None:
    results = [RouteCheckResult(name="City", minutes=56)]

    assert format_message(results, label="Work to Home") == "Work to Home: City 56"


def test_format_message_with_label_prefixes_the_failure_message_too() -> None:
    results = [RouteCheckResult(name="City", minutes=None, error="boom")]

    assert (
        format_message(results, label="Work to Home")
        == f"Work to Home: {FAILURE_MESSAGE}"
    )


def _fake_response(status_code: int, text: str = "") -> Any:
    class FakeResponse:
        def __init__(self) -> None:
            self.status_code = status_code
            self.text = text

    return FakeResponse()


@patch(
    "app.pushover.get_pushover_credentials",
    return_value=("app-token", "user-key"),
)
@patch("app.pushover.requests.post")
def test_send_notification_happy_path(mock_post: Any, _mock_creds: Any) -> None:
    mock_post.return_value = _fake_response(200)

    send_notification("City 56 · Mordor 50")

    sent_data = mock_post.call_args.kwargs["data"]
    assert sent_data == {
        "token": "app-token",
        "user": "user-key",
        "message": "City 56 · Mordor 50",
    }


@patch(
    "app.pushover.get_pushover_credentials",
    return_value=("app-token", "user-key"),
)
@patch("app.pushover.requests.post")
def test_send_notification_non_200(mock_post: Any, _mock_creds: Any) -> None:
    mock_post.return_value = _fake_response(400, text="invalid token")

    with pytest.raises(PushoverError, match="400"):
        send_notification("City 56")


@patch(
    "app.pushover.get_pushover_credentials",
    return_value=("app-token", "user-key"),
)
@patch("app.pushover.requests.post")
def test_send_notification_network_error(mock_post: Any, _mock_creds: Any) -> None:
    mock_post.side_effect = requests.ConnectionError("no route to host")

    with pytest.raises(PushoverError, match="could not reach"):
        send_notification("City 56")


@patch(
    "app.pushover.get_pushover_credentials",
    side_effect=MissingPushoverCredentialsError("no creds"),
)
def test_send_notification_missing_credentials(_mock_creds: Any) -> None:
    with pytest.raises(PushoverError, match="no creds"):
        send_notification("City 56")
