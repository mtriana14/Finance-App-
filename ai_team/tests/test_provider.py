"""Offline contract tests for the OpenAI provider adapter."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

import pytest
from pydantic import BaseModel

from libreta_ai.config import Settings
from libreta_ai.providers import (
    InvalidStructuredOutput,
    ModelProvider,
    OpenAIProvider,
    ProviderAuthenticationError,
    ProviderConfigurationError,
    ProviderFailure,
    ProviderRateLimitError,
    ProviderResult,
    ProviderTimeoutError,
    _SDKBindings,
)
from libreta_ai.schemas import EpistemicItem, FounderRequest


class FakeModelBehaviorError(Exception):
    pass


class FakeUserError(Exception):
    pass


class FakeSDKTimeout(Exception):
    pass


class FakeRateLimit(Exception):
    pass


class FakeAuthentication(Exception):
    pass


class FakePermissionDenied(Exception):
    pass


class FakeAgent:
    instances: list["FakeAgent"] = []

    def __init__(self, **values: Any) -> None:
        self.__dict__.update(values)
        self.instances.append(self)


class FakeModelSettings:
    instances: list["FakeModelSettings"] = []

    def __init__(self, **values: Any) -> None:
        self.__dict__.update(values)
        self.instances.append(self)


class FakeRunConfig:
    instances: list["FakeRunConfig"] = []

    def __init__(self, **values: Any) -> None:
        self.__dict__.update(values)
        self.instances.append(self)


class FakeSDKOpenAIProvider:
    instances: list["FakeSDKOpenAIProvider"] = []

    def __init__(self, **values: Any) -> None:
        self.__dict__.update(values)
        self.instances.append(self)


@dataclass
class FakeRawResponse:
    raw_usage: dict[str, int] | None = None
    model: str | None = None


@dataclass
class FakeRunResult:
    final_output: Any
    raw_responses: list[FakeRawResponse]
    last_agent: FakeAgent | None = None


class FakeRunner:
    outcomes: list[Any] = []
    calls: list[dict[str, Any]] = []

    @classmethod
    async def run(cls, agent: FakeAgent, input_text: str, **values: Any) -> Any:
        cls.calls.append({"agent": agent, "input_text": input_text, **values})
        outcome = cls.outcomes.pop(0)
        if isinstance(outcome, BaseException):
            raise outcome
        if callable(outcome):
            outcome = outcome()
        if asyncio.iscoroutine(outcome):
            outcome = await outcome
        if isinstance(outcome, FakeRunResult) and outcome.last_agent is None:
            outcome.last_agent = agent
        return outcome


@pytest.fixture(autouse=True)
def reset_fake_sdk(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    FakeAgent.instances.clear()
    FakeModelSettings.instances.clear()
    FakeRunConfig.instances.clear()
    FakeSDKOpenAIProvider.instances.clear()
    FakeRunner.outcomes.clear()
    FakeRunner.calls.clear()


@pytest.fixture
def fake_sdk() -> _SDKBindings:
    return _SDKBindings(
        agent_type=FakeAgent,
        runner=FakeRunner,
        run_config_type=FakeRunConfig,
        model_settings_type=FakeModelSettings,
        openai_model_provider_type=FakeSDKOpenAIProvider,
        invalid_output_errors=(FakeModelBehaviorError,),
        configuration_errors=(FakeUserError,),
        timeout_errors=(FakeSDKTimeout,),
        rate_limit_errors=(FakeRateLimit,),
        authentication_errors=(FakeAuthentication, FakePermissionDenied),
    )


def make_settings(**overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "openai_api_key": "unit-test-placeholder",
        "openai_model": "configured-model",
        "ai_team_provider_timeout_seconds": 0.1,
        "ai_team_enable_openai_tracing": False,
        "_env_file": None,
    }
    values.update(overrides)
    return Settings(**values)


def valid_item() -> EpistemicItem:
    return EpistemicItem(status="UNKNOWN", statement="Evidence is not available.")


def result_for(
    output: Any,
    *,
    raw_usage: dict[str, int] | None = None,
    returned_model: str | None = None,
) -> FakeRunResult:
    return FakeRunResult(
        final_output=output,
        raw_responses=[FakeRawResponse(raw_usage=raw_usage, model=returned_model)],
    )


def make_provider(
    fake_sdk: _SDKBindings,
    *,
    settings: Settings | None = None,
    clock: Any = None,
) -> OpenAIProvider:
    arguments: dict[str, Any] = {"_sdk_loader": lambda: fake_sdk}
    if clock is not None:
        arguments["_clock"] = clock
    return OpenAIProvider(settings or make_settings(), **arguments)


async def generate_item(provider: OpenAIProvider, **overrides: Any) -> ProviderResult[Any]:
    values: dict[str, Any] = {
        "role": "regulatory",
        "model": "explicit-model-2026-01-01",
        "instructions": "Return a structured regulatory assessment.",
        "input_text": "What evidence is available?",
        "output_type": EpistemicItem,
    }
    values.update(overrides)
    return await provider.generate(**values)


@pytest.mark.asyncio
async def test_success_returns_typed_application_result(fake_sdk: _SDKBindings) -> None:
    expected = valid_item()
    FakeRunner.outcomes = [result_for(expected)]
    result = await generate_item(make_provider(fake_sdk))
    assert isinstance(result, ProviderResult)
    assert result.output is expected
    assert isinstance(result.output, EpistemicItem)


@pytest.mark.asyncio
async def test_returned_model_identifier_is_mapped(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [result_for(valid_item(), returned_model="returned-model-id")]
    result = await generate_item(make_provider(fake_sdk))
    assert result.model == "returned-model-id"


@pytest.mark.asyncio
async def test_requested_model_is_fallback_when_sdk_has_no_identifier(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for(valid_item())]
    result = await generate_item(make_provider(fake_sdk), model="exact-model")
    assert result.model == "exact-model"


@pytest.mark.asyncio
async def test_input_and_output_tokens_are_mapped(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [
        result_for(valid_item(), raw_usage={"input_tokens": 41, "output_tokens": 17})
    ]
    result = await generate_item(make_provider(fake_sdk))
    assert result.input_tokens == 41
    assert result.output_tokens == 17


@pytest.mark.asyncio
async def test_missing_usage_is_none_not_fabricated(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [result_for(valid_item(), raw_usage=None)]
    result = await generate_item(make_provider(fake_sdk))
    assert result.input_tokens is None
    assert result.output_tokens is None


@pytest.mark.asyncio
async def test_partial_usage_preserves_missing_field_as_none(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for(valid_item(), raw_usage={"input_tokens": 9})]
    result = await generate_item(make_provider(fake_sdk))
    assert result.input_tokens == 9
    assert result.output_tokens is None


@pytest.mark.asyncio
async def test_latency_is_recorded(fake_sdk: _SDKBindings) -> None:
    times = iter((10.0, 10.125))
    FakeRunner.outcomes = [result_for(valid_item())]
    result = await generate_item(make_provider(fake_sdk, clock=lambda: next(times)))
    assert result.latency_ms == 125


@pytest.mark.asyncio
async def test_explicit_model_is_passed_unchanged(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [result_for(valid_item())]
    await generate_item(make_provider(fake_sdk), model="pinned-model-snapshot")
    assert FakeAgent.instances[0].model == "pinned-model-snapshot"


@pytest.mark.asyncio
async def test_instructions_are_passed_unchanged(fake_sdk: _SDKBindings) -> None:
    instructions = "Exact instructions\nwith preserved formatting."
    FakeRunner.outcomes = [result_for(valid_item())]
    await generate_item(make_provider(fake_sdk), instructions=instructions)
    assert FakeAgent.instances[0].instructions == instructions


@pytest.mark.asyncio
async def test_role_names_agent_without_enabling_delegation(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for(valid_item())]
    await generate_item(make_provider(fake_sdk), role="fundraising")
    agent = FakeAgent.instances[0]
    assert agent.name == "fundraising"
    assert agent.tools == []
    assert agent.handoffs == []
    assert agent.mcp_servers == []
    assert FakeRunner.calls[0]["max_turns"] == 1


@pytest.mark.asyncio
async def test_default_tracing_is_disabled_and_sensitive_data_excluded(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for(valid_item())]
    await generate_item(make_provider(fake_sdk))
    config = FakeRunConfig.instances[0]
    assert config.tracing_disabled is True
    assert config.trace_include_sensitive_data is False


@pytest.mark.asyncio
async def test_enabled_tracing_still_excludes_sensitive_data(
    fake_sdk: _SDKBindings,
) -> None:
    settings = make_settings(ai_team_enable_openai_tracing=True)
    FakeRunner.outcomes = [result_for(valid_item())]
    await generate_item(make_provider(fake_sdk, settings=settings))
    config = FakeRunConfig.instances[0]
    assert config.tracing_disabled is False
    assert config.trace_include_sensitive_data is False


@pytest.mark.asyncio
async def test_configured_timeout_bounds_sdk_and_application_call(
    fake_sdk: _SDKBindings,
) -> None:
    async def never_finishes() -> None:
        await asyncio.Event().wait()

    settings = make_settings(ai_team_provider_timeout_seconds=0.001)
    FakeRunner.outcomes = [never_finishes()]
    with pytest.raises(ProviderTimeoutError) as captured:
        await generate_item(make_provider(fake_sdk, settings=settings))
    assert captured.value.retryable is True
    assert FakeModelSettings.instances[0].timeout == 0.001


@pytest.mark.asyncio
async def test_sdk_timeout_is_mapped(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [FakeSDKTimeout("contains transport details")]
    with pytest.raises(ProviderTimeoutError):
        await generate_item(make_provider(fake_sdk))
    assert len(FakeRunner.calls) == 1


@pytest.mark.asyncio
async def test_authentication_failure_is_safe_and_not_retried(
    fake_sdk: _SDKBindings,
) -> None:
    secret = "unit-test-secret-that-must-not-be-exposed"
    FakeRunner.outcomes = [FakeAuthentication(f"invalid key {secret}")]
    with pytest.raises(ProviderAuthenticationError) as captured:
        await generate_item(make_provider(fake_sdk))
    assert len(FakeRunner.calls) == 1
    assert captured.value.retryable is False
    assert secret not in str(captured.value)
    assert secret not in repr(captured.value)


@pytest.mark.asyncio
async def test_authorization_failure_maps_to_authentication_category(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [FakePermissionDenied("forbidden")]
    with pytest.raises(ProviderAuthenticationError):
        await generate_item(make_provider(fake_sdk))


@pytest.mark.asyncio
async def test_rate_limit_is_safe_retryable_and_not_retried_by_adapter(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [FakeRateLimit("headers and request details")]
    with pytest.raises(ProviderRateLimitError) as captured:
        await generate_item(make_provider(fake_sdk))
    assert captured.value.retryable is True
    assert len(FakeRunner.calls) == 1
    assert "headers" not in str(captured.value)


@pytest.mark.asyncio
async def test_generic_sdk_failure_is_wrapped_safely(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [RuntimeError("raw provider payload")]
    with pytest.raises(ProviderFailure) as captured:
        await generate_item(make_provider(fake_sdk))
    assert captured.value.code == "provider_failure"
    assert "raw provider payload" not in str(captured.value)


@pytest.mark.asyncio
async def test_first_malformed_output_gets_one_retry(fake_sdk: _SDKBindings) -> None:
    expected = valid_item()
    FakeRunner.outcomes = [result_for("not typed"), result_for(expected)]
    result = await generate_item(make_provider(fake_sdk))
    assert result.output is expected
    assert len(FakeRunner.calls) == 2


@pytest.mark.asyncio
async def test_sdk_structured_output_error_gets_one_retry(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [FakeModelBehaviorError("bad JSON"), result_for(valid_item())]
    await generate_item(make_provider(fake_sdk))
    assert len(FakeRunner.calls) == 2


@pytest.mark.asyncio
async def test_second_malformed_output_raises_typed_error(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for("bad"), result_for({"still": "bad"})]
    with pytest.raises(InvalidStructuredOutput) as captured:
        await generate_item(make_provider(fake_sdk))
    assert len(FakeRunner.calls) == 2
    assert captured.value.retryable is False


@pytest.mark.asyncio
async def test_sdk_configuration_error_is_not_retried(fake_sdk: _SDKBindings) -> None:
    FakeRunner.outcomes = [FakeUserError("unsafe detail")]
    with pytest.raises(ProviderConfigurationError):
        await generate_item(make_provider(fake_sdk))
    assert len(FakeRunner.calls) == 1


@pytest.mark.asyncio
async def test_missing_api_key_fails_before_loading_sdk(fake_sdk: _SDKBindings) -> None:
    loader_called = False

    def loader() -> _SDKBindings:
        nonlocal loader_called
        loader_called = True
        return fake_sdk

    provider = OpenAIProvider(
        make_settings(openai_api_key=None),
        _sdk_loader=loader,
    )
    with pytest.raises(ProviderConfigurationError):
        await generate_item(provider)
    assert loader_called is False
    assert FakeRunner.calls == []


@pytest.mark.asyncio
async def test_raw_sdk_objects_do_not_escape_provider_result(
    fake_sdk: _SDKBindings,
) -> None:
    FakeRunner.outcomes = [result_for(valid_item())]
    result = await generate_item(make_provider(fake_sdk))
    assert set(result.__slots__) == {
        "output",
        "model",
        "latency_ms",
        "input_tokens",
        "output_tokens",
    }
    assert not hasattr(result, "raw_responses")
    assert not hasattr(result, "last_agent")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("output", "output_type"),
    [
        (EpistemicItem(status="UNKNOWN", statement="Unverified."), EpistemicItem),
        (FounderRequest(message="Assess the pilot."), FounderRequest),
    ],
)
async def test_provider_supports_multiple_existing_pydantic_types(
    fake_sdk: _SDKBindings,
    output: BaseModel,
    output_type: type[BaseModel],
) -> None:
    FakeRunner.outcomes = [result_for(output)]
    result = await generate_item(
        make_provider(fake_sdk), output_type=output_type, input_text="Valid input"
    )
    assert isinstance(result.output, output_type)


def test_openai_provider_satisfies_runtime_protocol(fake_sdk: _SDKBindings) -> None:
    assert isinstance(make_provider(fake_sdk), ModelProvider)


@pytest.mark.asyncio
async def test_non_pydantic_output_type_is_configuration_error(
    fake_sdk: _SDKBindings,
) -> None:
    provider = make_provider(fake_sdk)
    with pytest.raises(ProviderConfigurationError):
        await generate_item(provider, output_type=dict)
    assert FakeRunner.calls == []
