import json

import pytest
from pydantic import ValidationError

from app.config_models import Commute, Config, RouteDef
from app.settings import REPO_ROOT

SAMPLE_CONFIG_PATH = REPO_ROOT / "fixtures" / "sample-config.json"


def test_empty_config_is_valid() -> None:
    config = Config()
    assert config.commutes == []
    assert config.timezone == "America/Mexico_City"


def test_empty_commute_is_valid() -> None:
    commute = Commute(name="Work to Home")
    assert commute.origin is None
    assert commute.destination is None
    assert commute.routes == []
    assert commute.schedules == []


def test_route_rejects_out_of_range_latlng() -> None:
    with pytest.raises(ValidationError):
        RouteDef(name="City", color="#2563eb", via=[{"lat": 999, "lng": 0}])


def test_route_rejects_bad_color() -> None:
    with pytest.raises(ValidationError):
        RouteDef(name="City", color="blue", via=[])


def test_commute_rejects_duplicate_route_names() -> None:
    with pytest.raises(ValidationError, match="route names must be unique"):
        Commute(
            name="Work to Home",
            routes=[
                {"name": "City", "color": "#2563eb", "via": []},
                {"name": "City", "color": "#dc2626", "via": []},
            ],
        )


def test_commute_rejects_overlapping_schedule_weekdays() -> None:
    with pytest.raises(ValidationError, match="scheduled by more than one rule"):
        Commute(
            name="Home to Work",
            schedules=[
                {"weekdays": ["mon"], "time": "06:30"},
                {"weekdays": ["mon", "tue"], "time": "07:30"},
            ],
        )


def test_commute_allows_non_overlapping_schedule_rules() -> None:
    commute = Commute(
        name="Home to Work",
        schedules=[
            {"weekdays": ["mon"], "time": "06:30"},
            {"weekdays": ["tue", "wed", "thu", "fri"], "time": "07:30"},
        ],
    )
    assert len(commute.schedules) == 2


def test_schedule_rule_requires_at_least_one_weekday() -> None:
    with pytest.raises(ValidationError):
        Commute(name="Home to Work", schedules=[{"weekdays": [], "time": "06:30"}])


def test_config_rejects_duplicate_commute_names() -> None:
    with pytest.raises(ValidationError, match="commute names must be unique"):
        Config(
            commutes=[
                {"name": "Work to Home"},
                {"name": "Work to Home"},
            ]
        )


def test_shared_sample_config_fixture_validates() -> None:
    """The one config fixture api/ and web/ tests both load (prd.md §11) —
    if either side's schema drifts from the other, this (or its web/
    counterpart, configSchema.test.ts) is where it'd first show up."""
    data = json.loads(SAMPLE_CONFIG_PATH.read_text())

    config = Config.model_validate(data)

    assert [c.name for c in config.commutes] == ["Work to Home", "Home to Work"]
    work_to_home = config.commutes[0]
    assert work_to_home.origin is not None and work_to_home.origin.label == "Work"
    assert [r.name for r in work_to_home.routes] == ["City", "Mordor"]

    home_to_work = config.commutes[1]
    assert [rule.weekdays for rule in home_to_work.schedules] == [
        ["mon"],
        ["tue", "wed", "thu", "fri"],
    ]
