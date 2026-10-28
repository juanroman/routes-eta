"""Decoding of Google's encoded polyline format.

Ported from phase0/validate_api.py's decode_polyline() — no third-party
library needed for this.
"""

from __future__ import annotations


def decode_polyline(encoded: str) -> list[tuple[float, float]]:
    """Decode a Google encoded polyline (precision 5) into (lat, lng) pairs."""
    index, lat, lng = 0, 0, 0
    coordinates: list[tuple[float, float]] = []
    while index < len(encoded):
        for is_lng in (False, True):
            shift, result = 0, 0
            while True:
                byte = ord(encoded[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            delta = ~(result >> 1) if (result & 1) else (result >> 1)
            if is_lng:
                lng += delta
            else:
                lat += delta
        coordinates.append((lat / 1e5, lng / 1e5))
    return coordinates
