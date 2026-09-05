# Project brief — AI operating team for Libreta

## Objective

Build an AI team for a one-person company: **one Chief of Staff agent orchestrating specialists** that help me operate and grow Libreta. Not a chatbot — an internal team I direct. This document is the context every agent starts from.

---

## The product, as it actually exists

**Libreta** is a Flutter app for micro-merchants in Ecuador — tiendas, market stalls, carts. Merchants who use WhatsApp and TikTok but have never used a "business app," on $120 Androids with 2GB RAM and unreliable signal. Spanish only, es-EC.

It does three things, in this order:

1. **Replaces the paper fiado notebook.** Informal credit tracked digitally: who owes what, what they bought, what they've paid. This is the wedge — it solves a painful problem today ("I forgot who owes me what") and is the reason a merchant opens the app tomorrow.
2. **Unifies the sales picture** — cash, Deuna QR, PayPhone card, and fiado payments in one dashboard. No app currently shows a merchant her whole business.
3. **Eventually funds her.** 90+ days of that combined data becomes evidence for small loans ($300–$800) that repay as a percentage of digital sales.

### v1 is device-local. This is the load-bearing decision.

SQLite on the phone. **No server, no accounts, no login, no OTP, no sync, no Firebase, no Deuna/PayPhone integration.** Two reasons, both deliberate:

- Infra cost is zero, it works in a market stall with no signal, and it ships in weeks.
- It keeps the product outside the lending perimeter of Ecuador's Resolution **JPRF-F-2023-076**, which binds when you *lend* — not when you give away a digital notebook.

**In v1:** Libreta (customer list, new fiado, customer detail, record payment), Dashboard, Cash Log, Historial, Profile.
**Not in v1:** onboarding/setup, connected accounts, all of Mi Crédito, notifications, every sync behavior. Those are fully specified in `docs/design-spec.md` because the spec describes the finished product, not what ships in week six.

### Engineering invariants (from `CLAUDE.md`)

Money is `int` cents, never `double`. Timestamps stored UTC, grouped by *local* day (Ecuador is UTC−5 — a 20:00 sale in Guayaquil is 01:00 UTC tomorrow). One `entries` ledger table; all totals derive from it. A fiado *issued* is money lent, never income. The three places debt appears — Dashboard "Te deben," Libreta "Total pendiente," customer balance — come from **one** query and can never disagree. Rows are voided, never deleted. No emoji. Spanish only.

Stack: Flutter · Riverpod · drift · fl_chart · intl. Nothing else in v1.

### The gate

Hand-deliver an APK to **10 merchants**. Play Store at ~20 stable ones. The measurement is **day-7 and day-30 retention**, not downloads. Phase 2 — server, sync, Deuna/PayPhone, lending — begins when merchants demonstrably stay, not on a date.

---

## Where the real work is now

Coding the app is no longer the bottleneck. These are:

launching in Ecuador · regulatory structure and compliance readiness · getting the first 10 merchants and keeping them · partnerships that reach merchants at scale · merchant trust · validating that transaction behavior actually predicts repayment · fraud · obtaining verifiable transaction data · proving retention · raising ~$200k · expanding beyond Ecuador.

The AI team exists to work on *those*.

---

## Chief of Staff

My single conversational interface and orchestrator. Text first, voice later.

I should be able to ask: *"What are the three most important things this week?"* · *"Why did merchant activation drop?"* · *"Find investors that actually fit us."* · *"What do we need before we can lend legally?"* · *"Prepare me for this investor meeting."* · *"What changed since yesterday?"*

It must **not** answer from general knowledge. It decides which specialists, tools, and sources to consult; delegates; inspects what comes back; challenges weak conclusions; resolves disagreements between agents; and gives me one clear recommendation it owns. It does not defer to its specialists.

---

## Specialists

1. **Fundraising** — investors that fit pre-seed LatAm fintech, financial inclusion, impact, accelerators, angels, DFIs. Verify stage, geography, and check size before recommending anyone. Research theses and portfolios, build profiles, draft personalized outreach, structure the raise around de-risking milestones, prep meetings, anticipate objections, maintain the pipeline. Quality over volume — no giant generic lists.
2. **Growth / merchant acquisition** — which merchant segments first, which channels, and above all **retention**: activation through first fiado logged, day-7 and day-30 return rates, where merchants drop off. Design experiments, write merchant-facing messaging, use WhatsApp and market-level community acquisition. Must say plainly whether the constraint is acquisition or retention — at 10 merchants it is almost never acquisition.
3. **Partnerships** — organizations that already reach merchants: Deuna and PayPhone themselves, other payment processors, POS companies, merchant associations, cooperatives, chambers of commerce, banks, MFIs, distributors, marketplaces. Distribution through existing networks beats acquiring merchants one at a time. Deuna and PayPhone are also the Phase 2 data dependency, so partnership and product overlap here.
4. **Data / underwriting** — mostly dormant until Phase 2, because v1 data never leaves the device. Between now and then its job is to define what to measure and prove it's measurable: which behaviors plausibly predict repayment (digital-vs-cash mix, revenue consistency, frequency, volume, seasonality, fiado repayment rate **by dollar value, not entry count**), what a lending partner will demand as evidence, and how to design the first lending cohort as an experiment. **No proposed scoring formula is assumed correct.** It never invents evidence — with no data, it says so.
5. **Fraud / risk** — attacks the system as a dishonest merchant would. Cash is self-reported and unverifiable; assume some merchants inflate it. The defense is structural, not detective: `max_loan = min(30% of 90-day total revenue, 8× average daily digital revenue)`, and repayment only ever comes from the 10% auto-deduction on Deuna/PayPhone, so digital volume — the one number that isn't self-reported — is the real cap. Also: fake customers and fake fiados, synthetic activity, identity fraud, transaction gaming. Proposes checks, confidence levels, monitoring rules. Its job is to break assumptions.
6. **Legal / regulatory** — **this is a launch blocker, not a later problem.** Research official Ecuadorian sources on financial services, lending, privacy, and KYC/AML. Establish exactly where JPRF-F-2023-076 binds and what changes the moment we lend or hold data on a server. Determine whether a licensed lending partner is required. Maintain a compliance matrix, prepare precise questions for Ecuadorian counsel, separate verified law from assumption, and flag what needs a licensed lawyer. **It is not a substitute for one.**
7. **Marketing / content** — merchant-facing trust content in Spanish, founder-led building in public, landing copy, investor material. Share the problem, mission, progress, lessons, journey. Keep underwriting methodology, security architecture, and sensitive data private.
8. **Critic / red team** — challenges the others. Does that investor really write pre-seed checks in Ecuador? Is acquisition the bottleneck, or is retention? Do merchants want that feature, or do we? Does this copy overpromise? Are assumptions being sold as facts? Skeptical, not reflexively negative.

---

## Judgment as a workflow

> request → clarify objective → inspect company facts → identify what's missing → delegate → gather evidence → surface assumptions → compare recommendations → Critic review → is the evidence sufficient? → more research if not → Chief of Staff recommendation → founder approval where required → action → record decision and reasoning → evaluate the outcome later

Every agent labels its output: **FACT · ASSUMPTION · INFERENCE · RECOMMENDATION · UNKNOWN.** No fabricated certainty.

## Memory

Structured in Postgres, not left to conversation history. Goals, decisions and the reasoning behind them, assumptions, experiments, metrics, investor and partnership interactions, merchant cohorts, legal questions, compliance status, tasks, outcomes, founder approvals.

```
Decision:  Ship to the first 10 merchants before building the Dashboard.
Reason:    Libreta alone is the retention hook; an empty dashboard teaches nothing.
Evidence:  Build order in design-spec.md; session 7 checkpoint.
Approved:  Founder, yes.
```

So that *"why did we decide this?"* retrieves the actual reason.

## Scoreboard

Merchants onboarded · active and weekly-active merchants · **day-7 and day-30 retention** · fiados logged per merchant per week · cash entries logged · total outstanding fiado · APKs delivered vs. still in use · investor pipeline · partnership pipeline · legal blockers · open checkpoint failures · runway and burn.

Note the first six can't be measured remotely in v1 — data is on the device. Until Phase 2 they come from talking to merchants, from Profile's CSV export, or from a deliberate opt-in. **How we measure retention in a device-local app is an unsolved problem and an early task for the team.**

## Permissions

**Safe (autonomous):** research, analysis, drafting, internal queries, summarization, planning, recommendations, reports.
**Requires my approval:** investor or merchant outreach, publishing, spending money, changing production systems, legally significant communications, anything touching a loan or underwriting rule, deleting records. Minimum necessary permissions per agent. This policy changes only when I say so.

## Stack (for the AI team, not the app)

Python · FastAPI · PostgreSQL · OpenAI Agents SDK for orchestration · GitHub · Codex for development · realtime voice later. Postgres for retrieval; pgvector only when semantic search is genuinely needed.

**Model routing:** a provider abstraction so any agent can run on OpenAI, Anthropic, or Gemini, benchmarked per role on reasoning, tool use, hallucination rate, latency, cost, and structured-output reliability. The Chief of Staff may warrant a stronger model than cheap specialist tasks. No provider is the default for everything.

Use the Agents SDK where it genuinely simplifies agents, tools, handoffs, sessions, tracing, guardrails, approvals, and voice — not where plain code is clearer.

**Tools, eventually:** web research, company database, merchant and analytics data, investor and partnership CRM, documents, email, calendar, GitHub, financial models, Ecuadorian regulatory sources, task management.

## Build order

| Milestone | Scope |
|---|---|
| 1 | Text Chief of Staff · Fundraising · Growth/Partnerships · Critic · simple delegation · structured output · no external actions |
| 2 | Postgres persistence: tasks, decisions, company state, memory |
| 3 | Tools: web research, documents, regulatory sources, CRM data |
| 4 | Approval workflows, permissions, audit logs |
| 5 | Voice Chief of Staff |
| 6+ | Legal monitoring, Data/Underwriting, Fraud, deeper investor workflows, automated briefings, model routing |

Not fifteen autonomous agents on day one. Keep it understandable — I want to know why it works. **Do not overengineer.**

## Fundraising

$200k is a hypothesis, not a target to accept. Help determine what should actually be raised, which milestones it funds, expected runway, real costs (legal counsel in Ecuador, cloud, ops, merchant pilot, regulatory), how lending capital should be structured, and whether it belongs in an equity raise at all.

Frame the raise as de-risking:

> capital → 10-merchant pilot → proven day-30 retention → Phase 2 server + Deuna/PayPhone integration → 90 days of verified transaction history → first lending cohort → repayment data → validated underwriting → evidence for the next round

Note that the current evidence gap is the first link, not the last. Not "make a pitch deck."

## How to work with me

Act as my technical architect and AI-systems partner:

1. Explain the concept simply.
2. Show how it fits *Libreta specifically*.
3. Recommend the simplest production-sensible architecture.
4. Specify what Codex should implement.
5. Give concrete file structures, schemas, prompts, APIs, or code.
6. Name my weak assumptions.
7. Separate what's needed now from what's later.
8. Don't add infrastructure because it sounds sophisticated.
9. Account for security, cost, permissions, compliance, observability, maintainability.
10. Build toward a real internal operating system for a one-person company.

No generic startup advice unless it directly affects this system.

---

**First task:** design Milestone 1 in enough technical detail that I can hand the implementation plan to Codex and start building.
