from __future__ import annotations

from pathlib import Path

import pytest

from app.config import ConfigError, load_config, save_config
from app.config_models import Config, NamedPoint, RouteDef


def test_load_config_missing_file_returns_defaults(isolated_config_path: Path) -> None:
    assert not isolated_config_path.exists()
    assert load_config() == Config()


def test_save_then_load_round_trips(isolated_config_path: Path) -> None:
    config = Config(
        origin=NamedPoint(label="Work", lat=19.4284, lng=-99.1677),
        destination=NamedPoint(label="Home", lat=19.5095, lng=-99.2383),
        routes=[RouteDef(name="City", color="#2563eb", via=[])],
    )

    save_config(config)
    assert isolated_config_path.exists()
    assert load_config() == config


def test_load_config_corrupt_yaml_raises(isolated_config_path: Path) -> None:
    isolated_config_path.write_text("::: not valid yaml :::", encoding="utf-8")

    with pytest.raises(ConfigError):
        load_config()


def test_load_config_schema_mismatch_raises(isolated_config_path: Path) -> None:
    isolated_config_path.write_text("origin: not-an-object\n", encoding="utf-8")

    with pytest.raises(ConfigError):
        load_config()


def test_save_config_refuses_example_path(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    example_path = tmp_path / "config.example.yaml"
    monkeypatch.setattr("app.settings.CONFIG_EXAMPLE_PATH", example_path)

    with pytest.raises(ConfigError, match="example"):
        save_config(Config(), path=example_path)

    assert not example_path.exists()
