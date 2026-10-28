import pytest
from pydantic import ValidationError

from app.config_models import Config, RouteDef


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
