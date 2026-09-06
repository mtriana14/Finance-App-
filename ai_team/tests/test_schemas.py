"""Contract tests for schemas, runtime context, and role prompts."""

from __future__ import annotations

from copy import deepcopy

import pytest
from pydantic import ValidationError

from libreta_ai.prompt_loader import (
    PromptLoadError,
    build_instructions,
    load_company_context,
    load_role_prompt,
)
from libreta_ai.schemas import (
    ActionCategory,
    ActionItem,
    CriticFinding,
    CriticOutput,
    CriticVerdict,
    DelegationTask,
    EpistemicItem,
    EpistemicStatus,
    FinalChiefResponse,
    FinalResponseStatus,
    FindingSeverity,
    FounderRequest,
    RoutingDecision,
    SpecialistName,
    SpecialistOutput,
    WorkflowError,
    WorkflowStage,
)


def test_epistemic_status_values_are_exact() -> None:
    assert {status.value for status in EpistemicStatus} == {
        "FACT",
        "ASSUMPTION",
        "INFERENCE",
        "RECOMMENDATION",
        "UNKNOWN",
    }


def test_fact_with_evidence_is_valid() -> None:
    item = EpistemicItem(
        status="FACT", statement="Pilot length is about 60 days.", evidence_refs=["D1"]
    )
    assert item.status is EpistemicStatus.FACT


def test_fact_without_evidence_is_rejected() -> None:
    with pytest.raises(ValidationError, match="require at least one evidence"):
        EpistemicItem(status="FACT", statement="Unsupported fact")


@pytest.mark.parametrize(
    "status",
    ["ASSUMPTION", "INFERENCE", "RECOMMENDATION", "UNKNOWN"],
)
def test_non_fact_may_omit_evidence(status: str) -> None:
    item = EpistemicItem(status=status, statement="A properly labeled statement")
    assert item.evidence_refs == []


def test_blank_epistemic_statement_is_rejected() -> None:
    with pytest.raises(ValidationError):
        EpistemicItem(status="UNKNOWN", statement="  \t ")


def test_founder_request_is_trimmed() -> None:
    request = FounderRequest(message="  What should we test next?  ")
    assert request.message == "What should we test next?"


def test_blank_founder_request_is_rejected() -> None:
    with pytest.raises(ValidationError):
        FounderRequest(message=" \n ")


def test_oversized_founder_request_is_rejected() -> None:
    with pytest.raises(ValidationError):
        FounderRequest(message="x" * 10_001)


def test_specialist_targets_exclude_chief_and_critic() -> None:
    assert {specialist.value for specialist in SpecialistName} == {
        "fundraising",
        "growth_partnerships",
        "regulatory",
    }
    with pytest.raises(ValidationError):
        DelegationTask(specialist="critic", question="Review this")


def test_routing_rejects_duplicate_specialists(routing_data: dict[str, object]) -> None:
    data = deepcopy(routing_data)
    data["delegations"] = [
        {"specialist": "fundraising", "question": "Assess raise timing."},
        {"specialist": "fundraising", "question": "Assess raise size."},
    ]
    with pytest.raises(ValidationError, match="only once"):
        RoutingDecision.model_validate(data)


def test_routing_rejects_more_than_three_delegations(
    routing_data: dict[str, object],
) -> None:
    data = deepcopy(routing_data)
    data["delegations"] = [
        {"specialist": "fundraising", "question": "Question one"},
        {"specialist": "growth_partnerships", "question": "Question two"},
        {"specialist": "regulatory", "question": "Question three"},
        {"specialist": "fundraising", "question": "Question four"},
    ]
    with pytest.raises(ValidationError):
        RoutingDecision.model_validate(data)


def test_critic_required_needs_reason(routing_data: dict[str, object]) -> None:
    data = deepcopy(routing_data)
    data.update(critic_required=True, critic_reason=None)
    with pytest.raises(ValidationError, match="critic_reason"):
        RoutingDecision.model_validate(data)


def test_critic_required_rejects_blank_reason(routing_data: dict[str, object]) -> None:
    data = deepcopy(routing_data)
    data.update(critic_required=True, critic_reason="   ")
    with pytest.raises(ValidationError):
        RoutingDecision.model_validate(data)


def test_valid_routing_decision_preserves_reason(
    routing_data: dict[str, object],
) -> None:
    data = deepcopy(routing_data)
    data.update(critic_required=True, critic_reason="Material legal uncertainty.")
    decision = RoutingDecision.model_validate(data)
    assert decision.critic_reason == "Material legal uncertainty."


def test_internal_action_may_omit_approval() -> None:
    action = ActionItem(description="Draft an internal memo.", category="internal")
    assert action.requires_founder_approval is False


@pytest.mark.parametrize(
    "category",
    [
        "outreach",
        "publish",
        "spend",
        "production_change",
        "lending",
        "underwriting",
        "legal_communication",
        "destructive",
    ],
)
def test_non_internal_action_without_approval_is_rejected(category: str) -> None:
    with pytest.raises(ValidationError, match="require founder approval"):
        ActionItem(
            description="Perform an external or high-impact action.",
            category=category,
            requires_founder_approval=False,
        )


@pytest.mark.parametrize("category", list(ActionCategory)[1:])
def test_non_internal_action_with_approval_is_valid(category: ActionCategory) -> None:
    action = ActionItem(
        description="Prepare this action for founder review.",
        category=category,
        requires_founder_approval=True,
    )
    assert action.requires_founder_approval is True


def test_specialist_output_is_structured() -> None:
    output = SpecialistOutput(
        specialist="regulatory",
        analysis=[{"status": "UNKNOWN", "statement": "Legal structure is unresolved."}],
        proposed_actions=[
            {
                "description": "Draft questions for counsel.",
                "category": "internal",
            }
        ],
    )
    assert output.specialist is SpecialistName.REGULATORY


def test_critic_schema_accepts_actionable_finding() -> None:
    critic = CriticOutput(
        verdict="revise",
        findings=[
            {
                "severity": "blocking",
                "target": "recommendation",
                "epistemic_status": "ASSUMPTION",
                "problem": "The conclusion is presented as settled.",
                "required_change": "Relabel it and request evidence.",
            }
        ],
    )
    assert critic.verdict is CriticVerdict.REVISE
    assert critic.findings[0].severity is FindingSeverity.BLOCKING


def test_critic_rejects_unknown_verdict() -> None:
    with pytest.raises(ValidationError):
        CriticOutput(verdict="object", findings=[])


def test_critic_finding_rejects_extra_fields() -> None:
    with pytest.raises(ValidationError):
        CriticFinding(
            severity="warning",
            target="analysis",
            epistemic_status="INFERENCE",
            problem="Weak support.",
            required_change="Add support.",
            opinion="extra",
        )


def test_workflow_error_stage_values_are_exact() -> None:
    assert {stage.value for stage in WorkflowStage} == {
        "routing",
        "specialist",
        "critic",
        "synthesis",
    }
    error = WorkflowError(
        stage="specialist",
        agent="fundraising",
        code="invalid_output",
        message="The specialist response did not validate.",
        retryable=True,
    )
    assert error.stage is WorkflowStage.SPECIALIST


def test_final_recommendation_requires_recommendation_status(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data["recommendation"] = {
        "status": "FACT",
        "statement": "Run the pilot.",
        "evidence_refs": ["DECISIONS.md §42"],
    }
    with pytest.raises(ValidationError, match="RECOMMENDATION status"):
        FinalChiefResponse.model_validate(data)


def test_valid_final_recommendation_is_accepted(
    final_response_data: dict[str, object],
) -> None:
    response = FinalChiefResponse.model_validate(final_response_data)
    assert response.recommendation is not None
    assert response.recommendation.status is EpistemicStatus.RECOMMENDATION


def test_failed_response_cannot_have_recommendation(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data["status"] = "failed"
    data["errors"] = [
        {
            "stage": "synthesis",
            "agent": "chief_of_staff",
            "code": "invalid_output",
            "message": "Final synthesis failed validation.",
            "retryable": True,
        }
    ]
    with pytest.raises(ValidationError, match="cannot include a recommendation"):
        FinalChiefResponse.model_validate(data)


def test_failed_response_requires_an_error(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data.update(status="failed", recommendation=None, errors=[])
    with pytest.raises(ValidationError, match="requires at least one error"):
        FinalChiefResponse.model_validate(data)


def test_valid_failed_response_is_accepted(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data.update(
        status="failed",
        recommendation=None,
        errors=[
            {
                "stage": "routing",
                "agent": "chief_of_staff",
                "code": "provider_unavailable",
                "message": "No valid routing response was available.",
                "retryable": True,
            }
        ],
    )
    response = FinalChiefResponse.model_validate(data)
    assert response.status is FinalResponseStatus.FAILED


def test_final_response_rejects_extra_fields(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data["silent_status_fix"] = True
    with pytest.raises(ValidationError):
        FinalChiefResponse.model_validate(data)


def test_final_response_rejects_unapproved_nested_external_action(
    final_response_data: dict[str, object],
) -> None:
    data = deepcopy(final_response_data)
    data["next_actions"] = [
        {
            "description": "Email a potential partner.",
            "category": "outreach",
            "requires_founder_approval": False,
        }
    ]
    with pytest.raises(ValidationError):
        FinalChiefResponse.model_validate(data)


@pytest.mark.parametrize("status", ["ASSUMPTION", "UNKNOWN"])
def test_final_serialization_preserves_non_fact_status(
    final_response_data: dict[str, object], status: str
) -> None:
    data = deepcopy(final_response_data)
    data["analysis"] = [{"status": status, "statement": "Not established."}]
    dumped = FinalChiefResponse.model_validate(data).model_dump(mode="json")
    assert dumped["analysis"][0]["status"] == status


def test_company_context_declares_authoritative_source() -> None:
    context = load_company_context()
    opening = context[:500]
    assert "DECISIONS.md` is authoritative" in opening
    assert "DECISIONS.md` wins" in opening


def test_company_context_preserves_regulatory_unknowns() -> None:
    context = load_company_context()
    assert "UNKNOWN: whether Libreta may legally offer" in context
    assert "licensed lending partner is required" in context
    assert "20 merchants is exploratory only" in context


@pytest.mark.parametrize(
    "role",
    [
        "chief_of_staff",
        "fundraising",
        "growth_partnerships",
        "regulatory",
        "critic",
    ],
)
def test_all_role_prompts_load_and_require_epistemic_discipline(role: str) -> None:
    prompt = load_role_prompt(role)
    assert prompt
    assert "FACT" in prompt


def test_chief_prompt_owns_synthesis_and_approval_boundary() -> None:
    prompt = load_role_prompt("chief_of_staff")
    assert "own the final response" in prompt
    assert "do not concatenate" in prompt
    assert "founder approval" in prompt


def test_fundraising_prompt_requires_evidence_based_fit() -> None:
    prompt = load_role_prompt("fundraising")
    for dimension in ("stage", "geography", "check size", "thesis", "portfolio"):
        assert dimension in prompt
    assert "Do not manufacture investor lists" in prompt


def test_growth_prompt_separates_acquisition_and_retention() -> None:
    prompt = load_role_prompt("growth_partnerships")
    assert "Separate acquisition" in prompt
    assert "post-incentive" in prompt
    assert "payment providers" in prompt


def test_regulatory_prompt_disclaims_legal_authority() -> None:
    prompt = load_role_prompt("regulatory")
    assert "not a lawyer" in prompt
    assert "Never claim Libreta can lend" in prompt
    assert "qualified Ecuadorian counsel" in prompt


def test_critic_prompt_can_pass_without_performative_objections() -> None:
    prompt = load_role_prompt("critic")
    assert "may PASS sound work" in prompt
    assert "do not invent objections" in prompt


def test_build_instructions_combines_context_and_one_role() -> None:
    instructions = build_instructions("critic")
    assert "# Libreta company context" in instructions
    assert "# Role instructions" in instructions
    assert "# Critic" in instructions
    assert "# Fundraising specialist" not in instructions


def test_unknown_role_prompt_fails_clearly() -> None:
    with pytest.raises(PromptLoadError, match="Unknown role prompt"):
        load_role_prompt("../secrets")
