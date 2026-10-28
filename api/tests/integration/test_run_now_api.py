"""Web-to-API check for /run-now (prd.md §11): the real FastAPI app wired to
the real Google Routes API, proving config -> checker -> pushover.format_message
-> router are correctly connected end to end — something no mocked unit test
can catch. The Pushover send itself is mocked here; the one real push this
suite sends lives in test_pushover_integration.py (see that file's docstring
for why) so the call budget stays small and the costly send isn't duplicated.

Run with: uv run pytest -m integration. Makes 1 real Google Routes call.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from unittest.mock import patch

import pytest
from dotenv import load_dotenv
from fastapi.testclient import TestClient

from app.config import save_config
from app.config_models import Config, LatLng, NamedPoint, RouteDef
from app.main import app
from app.settings import REPO_ROOT

load_dotenv(REPO_ROOT / ".env")

pytestmark = pytest.mark.integration

ORIGIN = NamedPoint(label="Work", lat=19.4284, lng=-99.1677)
DESTINATION = NamedPoint(label="Home", lat=19.5095, lng=-99.2383)
VIA = [LatLng(lat=19.4550, lng=-99.2050)]


@pytest.mark.skipif(
    not os.environ.get("GOOGLE_ROUTES_API_KEY"),
    reason="GOOGLE_ROUTES_API_KEY not set — copy .env.example to .env to run this",
)
def test_run_now_endpoint_against_real_google_api(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    config_path = tmp_path / "config.yaml"
    monkeypatch.setattr("app.settings.CONFIG_PATH", config_path)
    save_config(
        Config(
            origin=ORIGIN,
            destination=DESTINATION,
            routes=[RouteDef(name="City", color="#2563eb", via=VIA)],
        ),
        path=config_path,
    )

    with patch("app.runner.send_notification") as mock_send:
        response = TestClient(app).post("/run-now")

    assert response.status_code == 200
    body = response.json()
    assert re.fullmatch(r"City \d+", body["message"])
    [result] = body["results"]
    assert result["name"] == "City"
    assert result["minutes"] > 0
    assert result["error"] is None
    mock_send.assert_called_once_with(body["message"])
