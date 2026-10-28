from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from app.settings import REPO_ROOT

# The one config fixture api/ and web/ tests both load (prd.md §11), so the
# live API's accepted shape can't silently diverge from what web/ expects.
VALID_BODY = json.loads((REPO_ROOT / "fixtures" / "sample-config.json").read_text())


def test_get_config_returns_defaults_when_no_file(
    client: TestClient, isolated_config_path: Path
) -> None:
    response = client.get("/config")

    assert response.status_code == 200
    assert response.json()["routes"] == []


def test_put_then_get_config_round_trips(
    client: TestClient, isolated_config_path: Path
) -> None:
    put_response = client.put("/config", json=VALID_BODY)
    assert put_response.status_code == 200
    assert isolated_config_path.exists()

    get_response = client.get("/config")
    assert get_response.json()["routes"][0]["name"] == "City"


def test_put_config_rejects_invalid_body_without_writing(
    client: TestClient, isolated_config_path: Path
) -> None:
    response = client.put("/config", json={"routes": [{"name": "City"}]})

    assert response.status_code == 422
    assert not isolated_config_path.exists()


def test_get_config_corrupt_file_returns_500(
    client: TestClient, isolated_config_path: Path
) -> None:
    isolated_config_path.write_text("::: not valid yaml :::", encoding="utf-8")

    response = client.get("/config")

    assert response.status_code == 500
