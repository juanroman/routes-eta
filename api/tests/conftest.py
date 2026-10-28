from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import app

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def compute_routes_response() -> dict[str, Any]:
    return json.loads((FIXTURES_DIR / "compute_routes_response.json").read_text())


@pytest.fixture
def compute_routes_duration_response() -> dict[str, Any]:
    return json.loads(
        (FIXTURES_DIR / "compute_routes_duration_response.json").read_text()
    )


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def isolated_config_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Redirect app.settings.CONFIG_PATH to a throwaway file for this test."""
    path = tmp_path / "config.yaml"
    monkeypatch.setattr("app.settings.CONFIG_PATH", path)
    return path
