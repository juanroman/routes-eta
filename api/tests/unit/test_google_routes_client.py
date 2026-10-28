from __future__ import annotations

from typing import Any
from unittest.mock import patch

import pytest
import requests

from app.config_models import LatLng
from app.google_routes_client import GoogleRoutesError, fetch_route_preview
from app.settings import MissingApiKeyError

ORIGIN = LatLng(lat=19.4284, lng=-99.1677)
DESTINATION = LatLng(lat=19.5095, lng=-99.2383)
VIA: list[LatLng] = [LatLng(lat=19.4550, lng=-99.2050)]


def _fake_response(status_code: int, json_body: Any = None, text: str = "") -> Any:
    class FakeResponse:
        def __init__(self) -> None:
            self.status_code = status_code
            self.text = text

        def json(self) -> Any:
            if json_body is None:
                raise ValueError("no JSON body")
            return json_body

    return FakeResponse()


@patch("app.google_routes_client.get_google_api_key", return_value="test-key")
@patch("app.google_routes_client.requests.post")
def test_fetch_route_preview_happy_path(
    mock_post: Any, _mock_key: Any, compute_routes_response: dict[str, Any]
) -> None:
    mock_post.return_value = _fake_response(200, compute_routes_response)

    result = fetch_route_preview(ORIGIN, DESTINATION, VIA)

    assert result.distance_meters == 18028
    assert result.encoded_polyline == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"


@patch("app.google_routes_client.get_google_api_key", return_value="test-key")
@patch("app.google_routes_client.requests.post")
def test_fetch_route_preview_non_200(mock_post: Any, _mock_key: Any) -> None:
    mock_post.return_value = _fake_response(403, text="permission denied")

    with pytest.raises(GoogleRoutesError, match="403"):
        fetch_route_preview(ORIGIN, DESTINATION, VIA)


@patch("app.google_routes_client.get_google_api_key", return_value="test-key")
@patch("app.google_routes_client.requests.post")
def test_fetch_route_preview_missing_fields(mock_post: Any, _mock_key: Any) -> None:
    mock_post.return_value = _fake_response(200, {"routes": [{}]})

    with pytest.raises(GoogleRoutesError, match="unexpected response shape"):
        fetch_route_preview(ORIGIN, DESTINATION, VIA)


@patch("app.google_routes_client.get_google_api_key", return_value="test-key")
@patch("app.google_routes_client.requests.post")
def test_fetch_route_preview_network_error(mock_post: Any, _mock_key: Any) -> None:
    mock_post.side_effect = requests.ConnectionError("no route to host")

    with pytest.raises(GoogleRoutesError, match="could not reach"):
        fetch_route_preview(ORIGIN, DESTINATION, VIA)


@patch(
    "app.google_routes_client.get_google_api_key",
    side_effect=MissingApiKeyError("no key"),
)
def test_fetch_route_preview_missing_key(_mock_key: Any) -> None:
    with pytest.raises(GoogleRoutesError, match="no key"):
        fetch_route_preview(ORIGIN, DESTINATION, VIA)
