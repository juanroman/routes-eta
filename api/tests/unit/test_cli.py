from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest

from app.checker import CheckerError, RouteCheckResult
from app.cli import main
from app.pushover import PushoverError
from app.runner import RunResult


@patch("app.runner.run_now")
def test_run_now_command_prints_message_and_exits_zero(
    mock_run_now: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    mock_run_now.return_value = RunResult(
        commute="Work to Home",
        message="Work to Home: City 56",
        results=[RouteCheckResult(name="City", minutes=56)],
    )

    exit_code = main(["run-now", "--commute", "Work to Home"])

    assert exit_code == 0
    assert capsys.readouterr().out.strip() == "Work to Home: City 56"
    mock_run_now.assert_called_once_with("Work to Home")


@patch("app.runner.run_now", side_effect=CheckerError("no routes are configured"))
def test_run_now_command_reports_checker_error_and_exits_one(
    _mock_run_now: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(["run-now", "--commute", "Work to Home"])

    assert exit_code == 1
    assert "no routes are configured" in capsys.readouterr().err


@patch("app.runner.run_now", side_effect=PushoverError("send failed"))
def test_run_now_command_reports_pushover_error_and_exits_one(
    _mock_run_now: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(["run-now", "--commute", "Work to Home"])

    assert exit_code == 1
    assert "send failed" in capsys.readouterr().err


def test_run_now_command_requires_commute_argument() -> None:
    with pytest.raises(SystemExit):
        main(["run-now"])


def test_crontab_command_prints_generated_script(
    capsys: pytest.CaptureFixture[str], isolated_config_path: Path
) -> None:
    exit_code = main(["crontab"])

    assert exit_code == 0
    assert "no commutes with a schedule configured" in capsys.readouterr().out


def test_main_requires_a_subcommand() -> None:
    with pytest.raises(SystemExit):
        main([])
