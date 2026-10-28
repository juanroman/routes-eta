"""Sends one real Pushover notification. Use sparingly (prd.md §11) — this is
deliberately the only real-send call site in the whole test suite, so running
`pytest -m integration` never fires more than one push no matter how many
other integration tests exist.

Run with: uv run pytest -m integration
"""

from __future__ import annotations

import os

import pytest
from dotenv import load_dotenv

from app.pushover import send_notification
from app.settings import REPO_ROOT

load_dotenv(REPO_ROOT / ".env")

pytestmark = pytest.mark.integration


@pytest.mark.skipif(
    not (os.environ.get("PUSHOVER_APP_TOKEN") and os.environ.get("PUSHOVER_USER_KEY")),
    reason="PUSHOVER_APP_TOKEN/PUSHOVER_USER_KEY not set — copy .env.example to "
    ".env to run this",
)
def test_send_notification_against_real_pushover_api() -> None:
    send_notification("Route ETA integration test — ignore")
