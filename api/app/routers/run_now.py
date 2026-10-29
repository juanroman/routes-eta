from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.checker import CheckerError
from app.pushover import PushoverError
from app.runner import run_now
from app.schemas import RouteResultSchema, RunNowRequest, RunNowResponse

router = APIRouter()


@router.post("/run-now", response_model=RunNowResponse)
def run_now_endpoint(request: RunNowRequest) -> RunNowResponse:
    try:
        result = run_now(request.commute)
    except CheckerError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PushoverError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return RunNowResponse(
        commute=result.commute,
        message=result.message,
        results=[
            RouteResultSchema(name=r.name, minutes=r.minutes, error=r.error)
            for r in result.results
        ],
    )
