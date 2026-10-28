"""Paths and environment-derived settings shared across the api/ app."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

APP_DIR = Path(__file__).resolve().parent
API_DIR = APP_DIR.parent
REPO_ROOT = API_DIR.parent

CONFIG_PATH = API_DIR / "config.yaml"
CONFIG_EXAMPLE_PATH = API_DIR / "config.example.yaml"

# The browser app's origin in dev (Vite's default port). The dev proxy means
# the browser normally never makes a cross-origin request at all, but FR-27
# requires this restriction regardless, as defense in depth.
WEB_ORIGIN = os.environ.get("WEB_ORIGIN", "http://localhost:5173")


class MissingApiKeyError(RuntimeError):
    """Raised when GOOGLE_ROUTES_API_KEY isn't set. A request-time failure, not
    a startup failure — the server must keep running so /config still works."""


def get_google_api_key() -> str:
    """Read GOOGLE_ROUTES_API_KEY from the repo-root .env, raising if unset.

    Called lazily by call sites that need it (not at import time), so the rest
    of the app keeps working with no key configured.
    """
    load_dotenv(REPO_ROOT / ".env")
    key = os.environ.get("GOOGLE_ROUTES_API_KEY")
    if not key:
        raise MissingApiKeyError(
            "GOOGLE_ROUTES_API_KEY is not set. Copy .env.example to .env at the "
            "repo root and fill in a real key."
        )
    return key
