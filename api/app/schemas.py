"""Transient request/response shapes for the JSON API — not persisted config."""

from __future__ import annotations

from pydantic import BaseModel

from app.config_models import LatLng


class PreviewRequest(BaseModel):
    origin: LatLng
    destination: LatLng
    via: list[LatLng] = []


class PreviewResponse(BaseModel):
    distance_meters: int
    polyline: list[tuple[float, float]]


class ErrorResponse(BaseModel):
    detail: str
