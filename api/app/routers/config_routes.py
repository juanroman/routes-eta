from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.config import ConfigError, load_config, save_config
from app.config_models import Config

router = APIRouter()


@router.get("/config", response_model=Config)
def get_config() -> Config:
    try:
        return load_config()
    except ConfigError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/config", response_model=Config)
def put_config(config: Config) -> Config:
    try:
        save_config(config)
    except ConfigError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return config
