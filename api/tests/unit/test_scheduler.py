from __future__ import annotations

from app.config_models import Config, Schedule
from app.scheduler import crontab_line
from app.settings import API_DIR


def test_crontab_line_maps_weekdays_and_time() -> None:
    config = Config(
        schedule=Schedule(weekdays=["mon", "tue", "wed", "thu", "fri"], time="18:30")
    )

    line = crontab_line(config)

    assert line.splitlines() == [
        "CRON_TZ=America/Mexico_City",
        f"30 18 * * 1,2,3,4,5 cd {API_DIR} && uv run python -m app.cli run-now "
        f">> {API_DIR}/checker.log 2>&1",
    ]


def test_crontab_line_sorts_unordered_weekdays() -> None:
    config = Config(schedule=Schedule(weekdays=["fri", "mon"], time="07:05"))

    line = crontab_line(config)

    assert "5 7 * * 1,5" in line


def test_crontab_line_uses_configured_timezone() -> None:
    config = Config(timezone="America/Los_Angeles")

    line = crontab_line(config)

    assert line.startswith("CRON_TZ=America/Los_Angeles\n")
