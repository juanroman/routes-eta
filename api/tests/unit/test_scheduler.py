from __future__ import annotations

from app.config_models import Commute, Config, ScheduleRule
from app.scheduler import NO_SCHEDULES_COMMENT, crontab_script
from app.settings import API_DIR


def test_crontab_script_maps_weekdays_and_time() -> None:
    config = Config(
        commutes=[
            Commute(
                name="Work to Home",
                schedules=[
                    ScheduleRule(
                        weekdays=["mon", "tue", "wed", "thu", "fri"], time="18:30"
                    )
                ],
            )
        ]
    )

    script = crontab_script(config)

    assert script.splitlines() == [
        "CRON_TZ=America/Mexico_City",
        f"30 18 * * 1,2,3,4,5 cd {API_DIR} && uv run python -m app.cli run-now "
        f"--commute 'Work to Home' >> {API_DIR}/checker.log 2>&1",
    ]


def test_crontab_script_sorts_unordered_weekdays() -> None:
    config = Config(
        commutes=[
            Commute(
                name="Work to Home",
                schedules=[ScheduleRule(weekdays=["fri", "mon"], time="07:05")],
            )
        ]
    )

    script = crontab_script(config)

    assert "5 7 * * 1,5" in script


def test_crontab_script_uses_configured_timezone() -> None:
    config = Config(
        timezone="America/Los_Angeles",
        commutes=[
            Commute(
                name="Work to Home",
                schedules=[ScheduleRule(weekdays=["mon"], time="07:05")],
            )
        ],
    )

    script = crontab_script(config)

    assert script.startswith("CRON_TZ=America/Los_Angeles\n")


def test_crontab_script_emits_one_line_per_commute_and_rule() -> None:
    config = Config(
        commutes=[
            Commute(
                name="Work to Home",
                schedules=[
                    ScheduleRule(
                        weekdays=["mon", "tue", "wed", "thu", "fri"], time="18:30"
                    )
                ],
            ),
            Commute(
                name="Home to Work",
                schedules=[
                    ScheduleRule(weekdays=["mon"], time="06:30"),
                    ScheduleRule(weekdays=["tue", "wed", "thu", "fri"], time="07:30"),
                ],
            ),
        ]
    )

    script = crontab_script(config)
    lines = script.splitlines()

    assert lines[0] == "CRON_TZ=America/Mexico_City"
    assert len(lines) == 4
    assert "--commute 'Work to Home'" in lines[1]
    assert lines[2].startswith("30 6 * * 1 ")
    assert "--commute 'Home to Work'" in lines[2]
    assert lines[3].startswith("30 7 * * 2,3,4,5 ")
    assert "--commute 'Home to Work'" in lines[3]


def test_crontab_script_quotes_commute_names_with_spaces() -> None:
    config = Config(
        commutes=[
            Commute(
                name="Work to Home",
                schedules=[ScheduleRule(weekdays=["mon"], time="18:30")],
            )
        ]
    )

    script = crontab_script(config)

    assert "--commute 'Work to Home'" in script


def test_crontab_script_with_no_schedules_returns_comment() -> None:
    config = Config(commutes=[Commute(name="Work to Home")])

    assert crontab_script(config) == NO_SCHEDULES_COMMENT


def test_crontab_script_with_no_commutes_returns_comment() -> None:
    assert crontab_script(Config()) == NO_SCHEDULES_COMMENT
