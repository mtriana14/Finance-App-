"""Tests for secret-safe AI team configuration."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
from pydantic import SecretStr, ValidationError

from libreta_ai.config import LogLevel, Settings


AI_TEAM_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = AI_TEAM_ROOT.parent
PROVIDER_ENV_NAMES = (
    "OPENAI_API_KEY",
    "OPENAI_MODEL",
    "AI_TEAM_PROVIDER_TIMEOUT_SECONDS",
    "AI_TEAM_LOG_LEVEL",
    "AI_TEAM_ENABLE_OPENAI_TRACING",
)


@pytest.fixture(autouse=True)
def clear_provider_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in PROVIDER_ENV_NAMES:
        monkeypatch.delenv(name, raising=False)


def settings_without_dotenv(**values: object) -> Settings:
    return Settings(_env_file=None, **values)


def test_configuration_loads_without_api_key() -> None:
    settings = settings_without_dotenv()

    assert settings.openai_api_key is None
    assert settings.ai_team_provider_timeout_seconds == 45
    assert settings.ai_team_log_level is LogLevel.INFO
    assert settings.ai_team_enable_openai_tracing is False


def test_missing_provider_configuration_is_detectable() -> None:
    settings = settings_without_dotenv()

    assert settings.provider_is_configured is False
    assert settings.provider_configuration_issues == (
        "OPENAI_API_KEY",
        "OPENAI_MODEL",
    )


def test_supplied_api_key_is_stored_as_secret() -> None:
    settings = settings_without_dotenv(
        openai_api_key="test-api-key-value",
        openai_model="test-model",
    )

    assert isinstance(settings.openai_api_key, SecretStr)
    assert settings.provider_is_configured is True


def test_configuration_representation_and_serialization_hide_api_key() -> None:
    raw_key = "test-api-key-value"
    settings = settings_without_dotenv(
        openai_api_key=raw_key,
        openai_model="test-model",
    )

    rendered_values = (
        repr(settings),
        str(settings),
        repr(settings.model_dump()),
        settings.model_dump_json(),
    )

    assert all(raw_key not in rendered for rendered in rendered_values)


@pytest.mark.parametrize("timeout", [0, -1, float("inf"), float("nan")])
def test_timeout_rejects_invalid_values(timeout: float) -> None:
    with pytest.raises(ValidationError):
        settings_without_dotenv(ai_team_provider_timeout_seconds=timeout)


@pytest.mark.parametrize(
    ("raw_value", "expected"),
    [("true", True), ("false", False), ("1", True), ("0", False)],
)
def test_tracing_boolean_parses(raw_value: str, expected: bool) -> None:
    settings = settings_without_dotenv(
        ai_team_enable_openai_tracing=raw_value,
    )

    assert settings.ai_team_enable_openai_tracing is expected


def test_tracing_boolean_rejects_unknown_value() -> None:
    with pytest.raises(ValidationError):
        settings_without_dotenv(ai_team_enable_openai_tracing="sometimes")


def test_log_level_is_normalized_and_unknown_values_are_rejected() -> None:
    assert (
        settings_without_dotenv(ai_team_log_level=" warning ").ai_team_log_level
        is LogLevel.WARNING
    )

    with pytest.raises(ValidationError):
        settings_without_dotenv(ai_team_log_level="VERBOSE")


def test_env_example_contains_no_usable_secret() -> None:
    values = dict(
        line.split("=", maxsplit=1)
        for line in (AI_TEAM_ROOT / ".env.example").read_text(
            encoding="utf-8"
        ).splitlines()
        if line and not line.startswith("#")
    )

    assert values["OPENAI_API_KEY"] == ""
    assert values["OPENAI_MODEL"] == ""
    assert not any(value.startswith("sk-") for value in values.values())


def test_gitignore_protects_env_but_allows_example() -> None:
    ignored = subprocess.run(
        ["git", "check-ignore", "-q", "--", "ai_team/.env"],
        cwd=REPO_ROOT,
        check=False,
    )
    example = subprocess.run(
        ["git", "check-ignore", "-q", "--", "ai_team/.env.example"],
        cwd=REPO_ROOT,
        check=False,
    )

    assert ignored.returncode == 0
    assert example.returncode == 1
