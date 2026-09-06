"""Provider-neutral model execution and the OpenAI Agents SDK adapter.

The adapter performs one bounded SDK run per attempt. It makes no tools or
handoffs available to the agent. A malformed structured output receives one
application retry; all other failures are mapped immediately and rely only on
the OpenAI SDK/client's own bounded transport retry behavior.
"""

from __future__ import annotations

import asyncio
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from time import perf_counter
from typing import Any, Generic, Protocol, TypeVar, runtime_checkable

from pydantic import BaseModel, ValidationError

from .config import Settings


T = TypeVar("T", bound=BaseModel)


@dataclass(frozen=True, slots=True)
class ProviderResult(Generic[T]):
    """Application-owned result returned by every model provider."""

    output: T
    model: str
    latency_ms: int
    input_tokens: int | None
    output_tokens: int | None


@runtime_checkable
class ModelProvider(Protocol):
    """Provider-neutral interface consumed by the future orchestrator."""

    async def generate(
        self,
        *,
        role: str,
        model: str,
        instructions: str,
        input_text: str,
        output_type: type[T],
    ) -> ProviderResult[T]:
        """Generate one validated structured model output."""


class ProviderError(Exception):
    """Base for safe, application-owned provider failures."""

    code = "provider_error"
    retryable = False
    default_message = "The model provider request failed."

    def __init__(self, safe_message: str | None = None) -> None:
        self.safe_message = safe_message or self.default_message
        super().__init__(self.safe_message)

    def __repr__(self) -> str:
        return (
            f"{type(self).__name__}(code={self.code!r}, "
            f"retryable={self.retryable!r}, safe_message={self.safe_message!r})"
        )


class ProviderConfigurationError(ProviderError):
    code = "configuration_error"
    default_message = "The model provider is not configured correctly."


class ProviderTimeoutError(ProviderError):
    code = "timeout"
    retryable = True
    default_message = "The model provider request timed out."


class ProviderRateLimitError(ProviderError):
    code = "rate_limit"
    retryable = True
    default_message = "The model provider rate limit was reached."


class ProviderAuthenticationError(ProviderError):
    code = "authentication_error"
    default_message = "The model provider rejected the configured credentials."


class InvalidStructuredOutput(ProviderError):
    code = "invalid_structured_output"
    default_message = "The model provider returned invalid structured output twice."


class ProviderFailure(ProviderError):
    code = "provider_failure"
    default_message = "The model provider request failed."


@dataclass(frozen=True, slots=True)
class _SDKBindings:
    """Private late-bound SDK surface, kept injectable for offline tests."""

    agent_type: type[Any]
    runner: Any
    run_config_type: type[Any]
    model_settings_type: type[Any]
    openai_model_provider_type: type[Any]
    invalid_output_errors: tuple[type[BaseException], ...]
    configuration_errors: tuple[type[BaseException], ...]
    timeout_errors: tuple[type[BaseException], ...]
    rate_limit_errors: tuple[type[BaseException], ...]
    authentication_errors: tuple[type[BaseException], ...]


def _available_exception_types(module: Any, *names: str) -> tuple[type[BaseException], ...]:
    found: list[type[BaseException]] = []
    for name in names:
        candidate = getattr(module, name, None)
        if isinstance(candidate, type) and issubclass(candidate, BaseException):
            found.append(candidate)
    return tuple(found)


def _load_sdk() -> _SDKBindings:
    """Import the pinned SDK lazily so configuration errors stay application-owned."""

    try:
        import agents
        import openai
        from agents.models.openai_provider import OpenAIProvider as SDKOpenAIProvider
    except ImportError:
        raise ProviderConfigurationError(
            "The OpenAI Agents SDK dependency is unavailable."
        ) from None

    return _SDKBindings(
        agent_type=agents.Agent,
        runner=agents.Runner,
        run_config_type=agents.RunConfig,
        model_settings_type=agents.ModelSettings,
        openai_model_provider_type=SDKOpenAIProvider,
        invalid_output_errors=_available_exception_types(
            agents, "ModelBehaviorError"
        ),
        configuration_errors=_available_exception_types(agents, "UserError"),
        timeout_errors=_available_exception_types(openai, "APITimeoutError"),
        rate_limit_errors=_available_exception_types(openai, "RateLimitError"),
        authentication_errors=_available_exception_types(
            openai, "AuthenticationError", "PermissionDeniedError"
        ),
    )


class _OutputTypeMismatch(TypeError):
    """Private marker for a typed SDK result with the wrong runtime type."""


class OpenAIProvider:
    """Thin, single-execution adapter for OpenAI Agents SDK 0.22.x."""

    _MAX_STRUCTURED_OUTPUT_ATTEMPTS = 2

    def __init__(
        self,
        settings: Settings,
        *,
        _sdk_loader: Callable[[], _SDKBindings] = _load_sdk,
        _clock: Callable[[], float] = perf_counter,
    ) -> None:
        self._settings = settings
        self._sdk_loader = _sdk_loader
        self._clock = _clock

    async def generate(
        self,
        *,
        role: str,
        model: str,
        instructions: str,
        input_text: str,
        output_type: type[T],
    ) -> ProviderResult[T]:
        """Run a typed agent once, retrying only one malformed structured output."""

        self._validate_request(role, model, instructions, input_text, output_type)
        api_key = self._settings.openai_api_key
        if api_key is None:
            raise ProviderConfigurationError(
                "OPENAI_API_KEY is required for OpenAI model execution."
            )

        sdk = self._sdk_loader()
        try:
            sdk_model_provider = sdk.openai_model_provider_type(
                api_key=api_key.get_secret_value()
            )
            model_settings = sdk.model_settings_type(
                timeout=self._settings.ai_team_provider_timeout_seconds,
                preserve_raw_usage=True,
            )
            agent = sdk.agent_type(
                name=role,
                instructions=instructions,
                model=model,
                model_settings=model_settings,
                output_type=output_type,
                tools=[],
                handoffs=[],
                mcp_servers=[],
            )
            run_config = sdk.run_config_type(
                model_provider=sdk_model_provider,
                tracing_disabled=not self._settings.ai_team_enable_openai_tracing,
                trace_include_sensitive_data=False,
                workflow_name="Libreta model generation",
            )
        except Exception as exc:
            raise self._map_error(exc, sdk) from None

        started_at = self._clock()
        for attempt in range(self._MAX_STRUCTURED_OUTPUT_ATTEMPTS):
            try:
                run = sdk.runner.run(
                    agent,
                    input_text,
                    max_turns=1,
                    run_config=run_config,
                )
                raw_result = await asyncio.wait_for(
                    run,
                    timeout=self._settings.ai_team_provider_timeout_seconds,
                )
                output = getattr(raw_result, "final_output", None)
                if not isinstance(output, output_type):
                    raise _OutputTypeMismatch

                input_tokens, output_tokens = _extract_usage(raw_result)
                return ProviderResult(
                    output=output,
                    model=_extract_model(raw_result, model),
                    latency_ms=max(0, round((self._clock() - started_at) * 1000)),
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                )
            except (ValidationError, _OutputTypeMismatch, *sdk.invalid_output_errors):
                if attempt + 1 < self._MAX_STRUCTURED_OUTPUT_ATTEMPTS:
                    continue
                raise InvalidStructuredOutput() from None
            except Exception as exc:
                raise self._map_error(exc, sdk) from None

        raise InvalidStructuredOutput()

    @staticmethod
    def _validate_request(
        role: str,
        model: str,
        instructions: str,
        input_text: str,
        output_type: type[BaseModel],
    ) -> None:
        if not all(
            isinstance(value, str) and value.strip()
            for value in (role, model, instructions, input_text)
        ):
            raise ProviderConfigurationError(
                "Role, model, instructions, and input text must be non-blank strings."
            )
        if not isinstance(output_type, type) or not issubclass(output_type, BaseModel):
            raise ProviderConfigurationError(
                "The requested output type must be a Pydantic model class."
            )

    @staticmethod
    def _map_error(exc: Exception, sdk: _SDKBindings) -> ProviderError:
        if isinstance(exc, ProviderError):
            return exc
        if isinstance(exc, (TimeoutError, *sdk.timeout_errors)):
            return ProviderTimeoutError()
        if isinstance(exc, sdk.rate_limit_errors):
            return ProviderRateLimitError()
        if isinstance(exc, sdk.authentication_errors):
            return ProviderAuthenticationError()
        if isinstance(exc, sdk.configuration_errors):
            return ProviderConfigurationError()
        return ProviderFailure()


def _token_value(value: Any) -> int | None:
    if type(value) is int and value >= 0:
        return value
    return None


def _extract_usage(raw_result: Any) -> tuple[int | None, int | None]:
    """Read only preserved raw usage so absent data is never turned into zero."""

    raw_responses = getattr(raw_result, "raw_responses", None)
    if not isinstance(raw_responses, list) or not raw_responses:
        return None, None

    input_total = 0
    output_total = 0
    input_seen = False
    output_seen = False
    for response in raw_responses:
        raw_usage = getattr(response, "raw_usage", None)
        if not isinstance(raw_usage, Mapping):
            continue
        input_value = _token_value(raw_usage.get("input_tokens"))
        output_value = _token_value(raw_usage.get("output_tokens"))
        if input_value is not None:
            input_total += input_value
            input_seen = True
        if output_value is not None:
            output_total += output_value
            output_seen = True

    return (
        input_total if input_seen else None,
        output_total if output_seen else None,
    )


def _extract_model(raw_result: Any, requested_model: str) -> str:
    """Prefer a returned model identifier, then fall back to the explicit request."""

    raw_responses = getattr(raw_result, "raw_responses", None)
    if isinstance(raw_responses, list):
        for response in reversed(raw_responses):
            for attribute in ("model", "model_name"):
                value = getattr(response, attribute, None)
                if isinstance(value, str) and value:
                    return value

    last_agent = getattr(raw_result, "last_agent", None)
    value = getattr(last_agent, "model", None)
    return value if isinstance(value, str) and value else requested_model
