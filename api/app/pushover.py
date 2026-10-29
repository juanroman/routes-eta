"""Pushover notification: one message per checker run (prd.md FR-15..19)."""

from __future__ import annotations

import requests

from app.checker import RouteCheckResult
from app.settings import MissingPushoverCredentialsError, get_pushover_credentials

PUSHOVER_URL = "https://api.pushover.net/1/messages.json"
REQUEST_TIMEOUT_S = 15
FAILURE_MESSAGE = "Couldn't fetch ETAs"


class PushoverError(Exception):
    """Raised when the Pushover notification could not be sent."""


def format_message(results: list[RouteCheckResult], label: str | None = None) -> str:
    """FR-16/17: "Name minutes" per route, " · "-joined, "Name ?" on failure.

    FR-18: if every route failed, a short failure message instead. Callers
    are expected to have already rejected an empty `results` list (an empty
    commute, not an all-failed run) via checker.check_commute.

    `label` (a commute's name) is prefixed to the message when given, so a
    notification is identifiable when more than one commute is configured.
    """
    if all(r.minutes is None for r in results):
        body = FAILURE_MESSAGE
    else:
        body = " · ".join(
            f"{r.name} {r.minutes}" if r.minutes is not None else f"{r.name} ?"
            for r in results
        )
    return f"{label}: {body}" if label else body


def send_notification(message: str) -> None:
    try:
        token, user_key = get_pushover_credentials()
    except MissingPushoverCredentialsError as exc:
        raise PushoverError(str(exc)) from exc

    try:
        response = requests.post(
            PUSHOVER_URL,
            data={"token": token, "user": user_key, "message": message},
            timeout=REQUEST_TIMEOUT_S,
        )
    except requests.RequestException as exc:
        raise PushoverError(f"could not reach Pushover: {exc}") from exc

    if response.status_code != 200:
        text = " ".join(response.text.split())[:160]
        raise PushoverError(f"Pushover returned {response.status_code}: {text}")
