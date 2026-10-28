"""Ties the checker and the Pushover notification together: the one thing
both the scheduled cron job and the manual "run now" command/endpoint invoke
(prd.md FR-15..19, FR-22, FR-26).
"""

from __future__ import annotations

from dataclasses import dataclass

from app.checker import RouteCheckResult, check_all_routes
from app.config import load_config
from app.pushover import format_message, send_notification


@dataclass
class RunResult:
    message: str
    results: list[RouteCheckResult]


def run_now() -> RunResult:
    """Load the config, check every route, and send one notification.

    Raises CheckerError if the config isn't complete enough to check (not a
    per-route failure, which check_all_routes already turns into "Name ?"),
    or PushoverError if the notification couldn't be sent.
    """
    config = load_config()
    results = check_all_routes(config)
    message = format_message(results)
    send_notification(message)
    return RunResult(message=message, results=results)
