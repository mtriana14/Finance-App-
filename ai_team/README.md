# Libreta AI Team

This directory contains Libreta's internal founder tool: a Chief of Staff that
will coordinate a small set of specialist AI agents. Milestone 1 is synchronous,
text-only, and has no external-action capabilities.

The merchant Flutter application remains independent, device-local, and is not
integrated with this backend. PostgreSQL, persistent memory, and background work
belong to later milestones.

## Setup

Python 3.11 or newer is required.

```powershell
cd ai_team
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
Copy-Item .env.example .env
```

Set `OPENAI_API_KEY` and an explicit `OPENAI_MODEL` in the local `.env` when a
later session adds provider calls. Never commit `.env`.

## Tests

Tests do not require network access or a real OpenAI key.

```powershell
python -m pytest
```
