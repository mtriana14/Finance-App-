"""Typed, secret-safe application configuration."""

from __future__ import annotations

import math
from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class LogLevel(str, Enum):
    """Log levels accepted by the application."""

    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class Settings(BaseSettings):
    """Configuration loaded from environment variables or ``ai_team/.env``."""

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    openai_api_key: SecretStr | None = None
    openai_model: str | None = None
    ai_team_provider_timeout_seconds: float = Field(default=45.0, gt=0)
    ai_team_log_level: LogLevel = LogLevel.INFO
    ai_team_enable_openai_tracing: bool = False

    @field_validator("openai_api_key", mode="before")
    @classmethod
    def blank_api_key_is_missing(cls, value: Any) -> Any:
        """Treat a blank key as absent while retaining ``SecretStr`` inputs."""

        if isinstance(value, SecretStr):
            return value if value.get_secret_value().strip() else None
        if isinstance(value, str) and not value.strip():
            return None
        return value

    @field_validator("openai_model", mode="before")
    @classmethod
    def normalize_model(cls, value: Any) -> Any:
        """Require an explicit non-blank model whenever a model is supplied."""

        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value

    @field_validator("ai_team_provider_timeout_seconds")
    @classmethod
    def timeout_must_be_finite(cls, value: float) -> float:
        """Reject non-finite timeout values in addition to non-positive ones."""

        if not math.isfinite(value):
            raise ValueError("provider timeout must be a finite positive number")
        return value

    @field_validator("ai_team_log_level", mode="before")
    @classmethod
    def normalize_log_level(cls, value: Any) -> Any:
        """Normalize string log levels and let the enum reject unknown values."""

        return value.strip().upper() if isinstance(value, str) else value

    @property
    def provider_configuration_issues(self) -> tuple[str, ...]:
        """Return missing provider setting names without revealing their values."""

        issues: list[str] = []
        if self.openai_api_key is None:
            issues.append("OPENAI_API_KEY")
        if self.openai_model is None:
            issues.append("OPENAI_MODEL")
        return tuple(issues)

    @property
    def provider_is_configured(self) -> bool:
        """Whether the OpenAI provider has every required setting."""

        return not self.provider_configuration_issues
