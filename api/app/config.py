"""Loading and saving the real (gitignored) config.yaml.

config.example.yaml is a tracked, illustrative file only — load_config() never
falls back to it, so an empty/missing real config correctly produces an empty
Config(), not fake placeholder data.
"""

from __future__ import annotations

from pathlib import Path

import yaml
from pydantic import ValidationError

from app import settings
from app.config_models import Config


class ConfigError(Exception):
    """Raised when the on-disk config exists but is malformed."""


def load_config(path: Path | None = None) -> Config:
    """Load the config, or return defaults if the file doesn't exist yet.

    `path` is resolved here (not as a bound default argument) so tests can
    monkeypatch app.settings.CONFIG_PATH and have it take effect.
    """
    resolved = path or settings.CONFIG_PATH
    if not resolved.exists():
        return Config()

    try:
        with resolved.open("r", encoding="utf-8") as f:
            raw = yaml.safe_load(f) or {}
    except yaml.YAMLError as exc:
        raise ConfigError(f"{resolved} is not valid YAML: {exc}") from exc

    try:
        return Config.model_validate(raw)
    except ValidationError as exc:
        raise ConfigError(
            f"{resolved} does not match the config schema: {exc}"
        ) from exc


def save_config(config: Config, path: Path | None = None) -> None:
    """Atomically write a validated Config to disk.

    Writes to a temp file and renames it into place, so a crash mid-write
    never corrupts the previously-saved config (prd.md FR-25).
    """
    resolved = path or settings.CONFIG_PATH
    if resolved == settings.CONFIG_EXAMPLE_PATH:
        raise ConfigError("refusing to overwrite the tracked example config")

    tmp_path = resolved.with_suffix(resolved.suffix + ".tmp")
    tmp_path.write_text(
        yaml.safe_dump(config.model_dump(mode="json"), sort_keys=False),
        encoding="utf-8",
    )
    tmp_path.replace(resolved)
