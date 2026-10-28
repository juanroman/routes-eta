from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest

from app.checker import CheckerError, RouteCheckResult
from app.pushover import PushoverError
from app.runner import run_now

# check_all_routes is mocked in every test below, so run_now()'s own
# load_config() call never needs a real config — isolated_config_path just
# keeps it from touching the real (gitignored) config.yaml.


@patch("app.runner.send_notification")
@patch(
    "app.runner.check_all_routes",
    return_value=[RouteCheckResult(name="City", minutes=56)],
)
def test_run_now_sends_the_formatted_message(
    _mock_check: Any, mock_send: Any, isolated_config_path: Path
) -> None:
    result = run_now()

    assert result.message == "City 56"
    assert result.results == [RouteCheckResult(name="City", minutes=56)]
    mock_send.assert_called_once_with("City 56")


@patch("app.runner.send_notification")
@patch("app.runner.check_all_routes", side_effect=CheckerError("no routes"))
def test_run_now_propagates_checker_error_without_sending(
    _mock_check: Any, mock_send: Any, isolated_config_path: Path
) -> None:
    with pytest.raises(CheckerError, match="no routes"):
        run_now()

    mock_send.assert_not_called()


@patch("app.runner.send_notification", side_effect=PushoverError("send failed"))
@patch(
    "app.runner.check_all_routes",
    return_value=[RouteCheckResult(name="City", minutes=56)],
)
def test_run_now_propagates_pushover_error(
    _mock_check: Any, _mock_send: Any, isolated_config_path: Path
) -> None:
    with pytest.raises(PushoverError, match="send failed"):
        run_now()
