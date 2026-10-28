from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.google_routes_client import GoogleRoutesError, fetch_route_preview
from app.polyline import decode_polyline
from app.schemas import PreviewRequest, PreviewResponse

router = APIRouter()


@router.post("/preview", response_model=PreviewResponse)
def preview_route(request: PreviewRequest) -> PreviewResponse:
    try:
        result = fetch_route_preview(request.origin, request.destination, request.via)
    except GoogleRoutesError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return PreviewResponse(
        distance_meters=result.distance_meters,
        polyline=decode_polyline(result.encoded_polyline),
    )
