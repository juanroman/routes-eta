"""Generates a crontab line from the config's schedule (prd.md FR-20..21).

cron itself handles "which weekdays" via the day-of-week field, so the
generated job is just "run once at this time on these days" — no in-process
scheduler is needed.
"""

from __future__ import annotations

from app.config_models import Config, Weekday
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

RUN_NOW_COMMAND = (
    "cd {api_dir} && uv run python -m app.cli run-now " ">> {api_dir}/checker.log 2>&1"
)


def crontab_line(config: Config) -> str:
    """A `CRON_TZ=` line plus the cron schedule line for `config.schedule`.

    `CRON_TZ` is honored by Debian/Raspberry Pi OS's cron, so the job runs at
    the configured local time regardless of the Pi's system timezone. On a
    cron that ignores `CRON_TZ`, set the system timezone to match instead.
    """
    hour_str, minute_str = config.schedule.time.split(":")
    days = ",".join(
        str(_CRON_WEEKDAY[day])
        for day in sorted(config.schedule.weekdays, key=lambda d: _CRON_WEEKDAY[d])
    )
    command = RUN_NOW_COMMAND.format(api_dir=API_DIR)
    return (
        f"CRON_TZ={config.timezone}\n"
        f"{int(minute_str)} {int(hour_str)} * * {days} {command}"
    )
