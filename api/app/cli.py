"""Command-line entry points for the checker (prd.md FR-21/22).

Runs standalone on the Raspberry Pi (no JSON API needed there, FR-28):

    uv run python -m app.cli run-now   # FR-22: send the notification now
    uv run python -m app.cli crontab   # FR-21: print the cron line to install
"""

from __future__ import annotations

import argparse
import sys

from app.checker import CheckerError
from app.config import load_config
from app.pushover import PushoverError
from app.scheduler import crontab_line


def _run_now_command() -> int:
    from app.runner import run_now

    try:
        result = run_now()
    except (CheckerError, PushoverError) as exc:
        print(f"Failed to send notification: {exc}", file=sys.stderr)
        return 1
    print(result.message)
    return 0


def _crontab_command() -> int:
    print(crontab_line(load_config()))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="route-eta-checker")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser(
        "run-now", help="Fetch ETAs now and send a Pushover notification"
    )
    subparsers.add_parser(
        "crontab", help="Print a crontab line for the configured schedule"
    )
    args = parser.parse_args(argv)

    if args.command == "run-now":
        return _run_now_command()
    return _crontab_command()


if __name__ == "__main__":
    raise SystemExit(main())
