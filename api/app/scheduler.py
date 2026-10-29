"""Generates a crontab script from the config's commutes (prd.md FR-20..21).

cron itself handles "which weekdays" via the day-of-week field, so each
generated job is just "run this commute once at this time on these days" —
no in-process scheduler is needed. One commute can have several schedule
rules (e.g. an earlier Monday departure), each becoming its own cron line.
"""

from __future__ import annotations

import shlex

from app.config_models import Commute, Config, ScheduleRule, Weekday
from app.settings import API_DIR

# Standard cron day-of-week: 0 (or 7) = Sunday ... 6 = Saturday.
_CRON_WEEKDAY: dict[Weekday, int] = {
    "sun": 0,
    "mon": 1,
    "tue": 2,
    "wed": 3,
    "thu": 4,
    "fri": 5,
    "sat": 6,
}

NO_SCHEDULES_COMMENT = "# no commutes with a schedule configured"

RUN_NOW_COMMAND = (
    "cd {api_dir} && uv run python -m app.cli run-now --commute {commute} "
    ">> {api_dir}/checker.log 2>&1"
)


def _cron_job_line(commute: Commute, rule: ScheduleRule) -> str:
    hour_str, minute_str = rule.time.split(":")
    days = ",".join(
        str(_CRON_WEEKDAY[day])
        for day in sorted(rule.weekdays, key=lambda d: _CRON_WEEKDAY[d])
    )
    command = RUN_NOW_COMMAND.format(api_dir=API_DIR, commute=shlex.quote(commute.name))
    return f"{int(minute_str)} {int(hour_str)} * * {days} {command}"


def crontab_script(config: Config) -> str:
    """A `CRON_TZ=` line plus one cron job line per (commute, schedule rule).

    `CRON_TZ` is honored by Debian/Raspberry Pi OS's cron, so every job runs
    at its configured local time regardless of the Pi's system timezone. On
    a cron that ignores `CRON_TZ`, set the system timezone to match instead.
    """
    lines = [
        _cron_job_line(commute, rule)
        for commute in config.commutes
        for rule in commute.schedules
    ]
    if not lines:
        return NO_SCHEDULES_COMMENT
    return f"CRON_TZ={config.timezone}\n" + "\n".join(lines)
