from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import config_routes, preview
from app.settings import WEB_ORIGIN


def create_app() -> FastAPI:
    app = FastAPI(title="Route ETA API")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[WEB_ORIGIN],
        allow_methods=["GET", "PUT", "POST"],
        allow_headers=["*"],
    )
    app.include_router(preview.router)
    app.include_router(config_routes.router)
    return app


app = create_app()

if __name__ == "__main__":
    import uvicorn

    # Bind to localhost only (prd.md FR-27) — never 0.0.0.0.
    uvicorn.run(app, host="127.0.0.1", port=8000)
