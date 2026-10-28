from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.config import ConfigError, load_config, save_config
from app.config_models import Config
from app.settings import REPO_ROOT

SAMPLE_CONFIG_PATH = REPO_ROOT / "fixtures" / "sample-config.json"


def test_load_config_missing_file_returns_defaults(isolated_config_path: Path) -> None:
    assert not isolated_config_path.exists()
    assert load_config() == Config()


def test_save_then_load_round_trips(isolated_config_path: Path) -> None:
    config = Config.model_validate(json.loads(SAMPLE_CONFIG_PATH.read_text()))

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
