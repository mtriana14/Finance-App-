"""Shared fixtures for schema-contract tests."""

from __future__ import annotations

import pytest


@pytest.fixture
def final_response_data() -> dict[str, object]:
    """Return a minimal valid completed Chief of Staff response."""

    return {
        "request_id": "request-001",
        "status": "completed",
        "objective": "Choose the next pilot learning milestone.",
        "recommendation": {
            "status": "RECOMMENDATION",
            "statement": "Prioritize legitimate Day 7 retention learning.",
            "evidence_refs": [],
        },
        "analysis": [
            {
                "status": "FACT",
                "statement": "The working pilot cohort is approximately 20 merchants.",
                "evidence_refs": ["DECISIONS.md §42"],
            }
        ],
        "specialists_consulted": ["growth_partnerships"],
        "critic": {"verdict": "pass", "findings": []},
        "missing_information": [],
        "next_actions": [
            {
                "description": "Draft the internal Day 7 interview guide.",
                "category": "internal",
            }
        ],
        "errors": [],
    }


@pytest.fixture
def routing_data() -> dict[str, object]:
    """Return a minimal valid routing decision."""

    return {
        "objective": "Assess pilot readiness.",
        "missing_information": [],
        "delegations": [
            {
                "specialist": "growth_partnerships",
                "question": "Which activation signal should the pilot test first?",
            }
        ],
        "rationale": "The request concerns merchant behavior.",
        "critic_required": False,
        "critic_reason": None,
    }
