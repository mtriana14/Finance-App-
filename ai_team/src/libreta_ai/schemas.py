"""Strict data contracts for the Milestone 1 AI workflow."""

from __future__ import annotations

from enum import Enum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator


NonBlankText = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=10_000),
]
EvidenceReference = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=500),
]


class StrictSchema(BaseModel):
    """Base schema that rejects unrecognized fields and trims strings."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class EpistemicStatus(str, Enum):
    """How strongly a statement is supported."""

    FACT = "FACT"
    ASSUMPTION = "ASSUMPTION"
    INFERENCE = "INFERENCE"
    RECOMMENDATION = "RECOMMENDATION"
    UNKNOWN = "UNKNOWN"


class SpecialistName(str, Enum):
    """Specialists to which the Chief of Staff may delegate."""

    FUNDRAISING = "fundraising"
    GROWTH_PARTNERSHIPS = "growth_partnerships"
    REGULATORY = "regulatory"


class EpistemicItem(StrictSchema):
    """A statement paired with its epistemic status and source references."""

    status: EpistemicStatus
    statement: NonBlankText
    evidence_refs: list[EvidenceReference] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def facts_require_evidence(self) -> "EpistemicItem":
        if self.status is EpistemicStatus.FACT and not self.evidence_refs:
            raise ValueError("FACT statements require at least one evidence reference")
        return self


class FounderRequest(StrictSchema):
    """A normalized request from the founder."""

    message: Annotated[
        str,
        StringConstraints(strip_whitespace=True, min_length=1, max_length=10_000),
    ]


class DelegationTask(StrictSchema):
    """One bounded question assigned to an eligible specialist."""

    specialist: SpecialistName
    question: NonBlankText


class RoutingDecision(StrictSchema):
    """The Chief of Staff's bounded routing plan."""

    objective: NonBlankText
    missing_information: list[NonBlankText] = Field(default_factory=list, max_length=50)
    delegations: list[DelegationTask] = Field(default_factory=list, max_length=3)
    rationale: NonBlankText
    critic_required: bool
    critic_reason: NonBlankText | None = None

    @model_validator(mode="after")
    def validate_routing_invariants(self) -> "RoutingDecision":
        specialists = [task.specialist for task in self.delegations]
        if len(specialists) != len(set(specialists)):
            raise ValueError("a specialist may appear only once in a routing decision")
        if self.critic_required and self.critic_reason is None:
            raise ValueError("critic_reason is required when critic_required is true")
        return self


class ActionCategory(str, Enum):
    """Risk category for a proposed action."""

    INTERNAL = "internal"
    OUTREACH = "outreach"
    PUBLISH = "publish"
    SPEND = "spend"
    PRODUCTION_CHANGE = "production_change"
    LENDING = "lending"
    UNDERWRITING = "underwriting"
    LEGAL_COMMUNICATION = "legal_communication"
    DESTRUCTIVE = "destructive"


class ActionItem(StrictSchema):
    """A proposed action with an explicit founder-approval boundary."""

    description: NonBlankText
    category: ActionCategory
    requires_founder_approval: bool = Field(default=False, strict=True)

    @model_validator(mode="after")
    def external_actions_require_approval(self) -> "ActionItem":
        if (
            self.category is not ActionCategory.INTERNAL
            and not self.requires_founder_approval
        ):
            raise ValueError("all non-internal actions require founder approval")
        return self


class SpecialistOutput(StrictSchema):
    """Structured specialist analysis returned to the Chief of Staff."""

    specialist: SpecialistName
    analysis: list[EpistemicItem] = Field(default_factory=list, max_length=100)
    proposed_actions: list[ActionItem] = Field(default_factory=list, max_length=50)


class CriticVerdict(str, Enum):
    """Possible conclusions of the Critic review."""

    PASS = "pass"
    REVISE = "revise"
    INSUFFICIENT_EVIDENCE = "insufficient_evidence"


class FindingSeverity(str, Enum):
    """Severity of a Critic finding."""

    WARNING = "warning"
    BLOCKING = "blocking"


class CriticFinding(StrictSchema):
    """One actionable issue identified by the Critic."""

    severity: FindingSeverity
    target: NonBlankText
    epistemic_status: EpistemicStatus
    problem: NonBlankText
    required_change: NonBlankText


class CriticOutput(StrictSchema):
    """The Critic's verdict and supporting findings."""

    verdict: CriticVerdict
    findings: list[CriticFinding] = Field(default_factory=list, max_length=100)


class WorkflowStage(str, Enum):
    """Workflow stages that may emit a structured error."""

    ROUTING = "routing"
    SPECIALIST = "specialist"
    CRITIC = "critic"
    SYNTHESIS = "synthesis"


class WorkflowError(StrictSchema):
    """A safe, structured failure captured during orchestration."""

    stage: WorkflowStage
    agent: NonBlankText | None = None
    code: NonBlankText
    message: NonBlankText
    retryable: bool = Field(strict=True)


class FinalResponseStatus(str, Enum):
    """Completion state of the Chief of Staff response."""

    COMPLETED = "completed"
    PARTIAL = "partial"
    NEEDS_INFORMATION = "needs_information"
    FAILED = "failed"


class FinalChiefResponse(StrictSchema):
    """Validated final response owned by the Chief of Staff."""

    request_id: NonBlankText
    status: FinalResponseStatus
    objective: NonBlankText
    recommendation: EpistemicItem | None
    analysis: list[EpistemicItem] = Field(default_factory=list, max_length=200)
    specialists_consulted: list[SpecialistName] = Field(
        default_factory=list, max_length=3
    )
    critic: CriticOutput | None = None
    missing_information: list[NonBlankText] = Field(default_factory=list, max_length=50)
    next_actions: list[ActionItem] = Field(default_factory=list, max_length=50)
    errors: list[WorkflowError] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def validate_final_response_invariants(self) -> "FinalChiefResponse":
        if (
            self.recommendation is not None
            and self.recommendation.status is not EpistemicStatus.RECOMMENDATION
        ):
            raise ValueError("recommendation must have RECOMMENDATION status")
        if self.status is FinalResponseStatus.FAILED:
            if self.recommendation is not None:
                raise ValueError("a failed response cannot include a recommendation")
            if not self.errors:
                raise ValueError("a failed response requires at least one error")
        return self
