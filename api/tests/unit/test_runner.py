from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest

from app.checker import CheckerError, RouteCheckResult
from app.config import save_config
from app.config_models import Commute, Config
from app.pushover import PushoverError
from app.runner import run_now

# check_commute is mocked in every test below, so run_now()'s own
# load_config() call never needs a real config beyond naming the commute it
# looks up — isolated_config_path just keeps it from touching the real
# (gitignored) config.yaml.


def _save(isolated_config_path: Path, *names: str) -> None:
    save_config(
        Config(commutes=[Commute(name=name) for name in names]),
        path=isolated_config_path,
    )


@patch("app.runner.send_notification")
@patch(
    "app.runner.check_commute",
    return_value=[RouteCheckResult(name="City", minutes=56)],
)
def test_run_now_sends_the_formatted_message(
    _mock_check: Any, mock_send: Any, isolated_config_path: Path
) -> None:
    _save(isolated_config_path, "Work to Home")

    result = run_now("Work to Home")

    assert result.commute == "Work to Home"
    assert result.message == "Work to Home: City 56"
    assert result.results == [RouteCheckResult(name="City", minutes=56)]
    mock_send.assert_called_once_with("Work to Home: City 56")


def test_run_now_raises_for_unknown_commute(isolated_config_path: Path) -> None:
    _save(isolated_config_path, "Work to Home")

    with pytest.raises(CheckerError, match="no commute named 'Home to Work'"):
        run_now("Home to Work")


@patch("app.runner.send_notification")
@patch("app.runner.check_commute", side_effect=CheckerError("no routes"))
def test_run_now_propagates_checker_error_without_sending(
    _mock_check: Any, mock_send: Any, isolated_config_path: Path
) -> None:
    _save(isolated_config_path, "Work to Home")

    with pytest.raises(CheckerError, match="no routes"):
        run_now("Work to Home")

    mock_send.assert_not_called()


@patch("app.runner.send_notification", side_effect=PushoverError("send failed"))
@patch(
    "app.runner.check_commute",
    return_value=[RouteCheckResult(name="City", minutes=56)],
)
def test_run_now_propagates_pushover_error(
    _mock_check: Any, _mock_send: Any, isolated_config_path: Path
) -> None:
    _save(isolated_config_path, "Work to Home")

    with pytest.raises(PushoverError, match="send failed"):
        run_now("Work to Home")
