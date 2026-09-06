"""Package-relative loading for Libreta's context and role prompts."""

from __future__ import annotations

from pathlib import Path


_PACKAGE_DIR = Path(__file__).resolve().parent
_COMPANY_CONTEXT = _PACKAGE_DIR / "context" / "company.md"
_ROLE_PROMPTS = {
    "chief_of_staff": _PACKAGE_DIR / "prompts" / "chief_of_staff.md",
    "fundraising": _PACKAGE_DIR / "prompts" / "fundraising.md",
    "growth_partnerships": _PACKAGE_DIR / "prompts" / "growth_partnerships.md",
    "regulatory": _PACKAGE_DIR / "prompts" / "regulatory.md",
    "critic": _PACKAGE_DIR / "prompts" / "critic.md",
}


class PromptLoadError(RuntimeError):
    """Raised when a required packaged prompt cannot be read."""


def _read_prompt(path: Path, label: str) -> str:
    try:
        content = path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise PromptLoadError(f"Unable to load {label}: {exc}") from exc
    if not content:
        raise PromptLoadError(f"Unable to load {label}: file is empty")
    return content


def load_company_context() -> str:
    """Load the curated runtime snapshot bundled with this package."""

    return _read_prompt(_COMPANY_CONTEXT, "company context")


def load_role_prompt(role_name: str) -> str:
    """Load a known role prompt without accepting arbitrary filesystem paths."""

    normalized_name = role_name.strip().lower()
    path = _ROLE_PROMPTS.get(normalized_name)
    if path is None:
        known_roles = ", ".join(sorted(_ROLE_PROMPTS))
        raise PromptLoadError(
            f"Unknown role prompt {role_name!r}; expected one of: {known_roles}"
        )
    return _read_prompt(path, f"role prompt {normalized_name!r}")


def build_instructions(role_name: str) -> str:
    """Combine shared company context with one role's operating instructions."""

    return (
        "# Libreta company context\n\n"
        f"{load_company_context()}\n\n"
        "---\n\n"
        "# Role instructions\n\n"
        f"{load_role_prompt(role_name)}"
    )
