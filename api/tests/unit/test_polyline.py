import pytest

from app.polyline import decode_polyline


def test_decode_polyline_known_example() -> None:
    # The example encoded string from Google's own polyline algorithm docs.
    encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    expected = [
        (38.5, -120.2),
        (40.7, -120.95),
        (43.252, -126.453),
    ]

    decoded = decode_polyline(encoded)

    assert len(decoded) == len(expected)
    for (lat, lng), (exp_lat, exp_lng) in zip(decoded, expected, strict=True):
        assert lat == pytest.approx(exp_lat, abs=1e-5)
        assert lng == pytest.approx(exp_lng, abs=1e-5)


def test_decode_polyline_empty_string() -> None:
    assert decode_polyline("") == []
