import json

import pytest
from pydantic import ValidationError

from app.config_models import Config, RouteDef
from app.settings import REPO_ROOT

SAMPLE_CONFIG_PATH = REPO_ROOT / "fixtures" / "sample-config.json"


def test_empty_config_is_valid() -> None:
    config = Config()
    assert config.origin is None
    assert config.destination is None
    assert config.routes == []
    assert config.timezone == "America/Mexico_City"


def test_route_rejects_out_of_range_latlng() -> None:
    with pytest.raises(ValidationError):
        RouteDef(name="City", color="#2563eb", via=[{"lat": 999, "lng": 0}])


def test_route_rejects_bad_color() -> None:
    with pytest.raises(ValidationError):
        RouteDef(name="City", color="blue", via=[])


def test_config_rejects_duplicate_route_names() -> None:
    with pytest.raises(ValidationError, match="unique"):
        Config(
            routes=[
                {"name": "City", "color": "#2563eb", "via": []},
                {"name": "City", "color": "#dc2626", "via": []},
            ]
        )


def test_shared_sample_config_fixture_validates() -> None:
    """The one config fixture api/ and web/ tests both load (prd.md §11) —
    if either side's schema drifts from the other, this (or its web/
    counterpart, configSchema.test.ts) is where it'd first show up."""
    data = json.loads(SAMPLE_CONFIG_PATH.read_text())

    config = Config.model_validate(data)

    assert config.origin is not None and config.origin.label == "Work"
    assert [r.name for r in config.routes] == ["City", "Mordor"]
