from __future__ import annotations

from typing import Any
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.google_routes_client import GoogleRoutesError, RoutePreview

VALID_BODY = {
    "origin": {"lat": 19.4284, "lng": -99.1677},
    "destination": {"lat": 19.5095, "lng": -99.2383},
    "via": [{"lat": 19.4550, "lng": -99.2050}],
}


@patch("app.routers.preview.fetch_route_preview")
def test_preview_success(mock_fetch: Any, client: TestClient) -> None:
    mock_fetch.return_value = RoutePreview(
        distance_meters=18028, encoded_polyline="_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    )

    response = client.post("/preview", json=VALID_BODY)

    assert response.status_code == 200
    body = response.json()
    assert body["distance_meters"] == 18028
    assert len(body["polyline"]) == 3


@patch("app.routers.preview.fetch_route_preview")
def test_preview_google_error_returns_502(mock_fetch: Any, client: TestClient) -> None:
    mock_fetch.side_effect = GoogleRoutesError("Google Routes API returned 403")

    response = client.post("/preview", json=VALID_BODY)

    assert response.status_code == 502
    assert "403" in response.json()["detail"]


def test_preview_rejects_invalid_payload(client: TestClient) -> None:
    response = client.post("/preview", json={"origin": {"lat": 999, "lng": 0}})

    assert response.status_code == 422
