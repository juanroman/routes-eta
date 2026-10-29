"""Ties the checker and the Pushover notification together: the one thing
both the scheduled cron job and the manual "run now" command/endpoint invoke
(prd.md FR-15..19, FR-22, FR-26).
"""

from __future__ import annotations

from dataclasses import dataclass

from app.checker import CheckerError, RouteCheckResult, check_commute
from app.config import load_config
from app.pushover import format_message, send_notification


@dataclass
class RunResult:
    commute: str
    message: str
    results: list[RouteCheckResult]


def run_now(commute_name: str) -> RunResult:
    """Load the config, check the named commute's routes, and send one
    notification.

    Raises CheckerError if no commute with that name exists, or if the
    commute isn't configured completely enough to check (not a per-route
    failure, which check_commute already turns into "Name ?"), or
    PushoverError if the notification couldn't be sent.
    """
    config = load_config()
    commute = next((c for c in config.commutes if c.name == commute_name), None)
    if commute is None:
        raise CheckerError(f"no commute named {commute_name!r}")

    results = check_commute(commute)
    message = format_message(results, label=commute.name)
    send_notification(message)
    return RunResult(commute=commute.name, message=message, results=results)
