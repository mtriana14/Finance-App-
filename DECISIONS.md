# DECISIONS.md

## 1. Build Libreta as a one-person company supported by an AI team

**Decision**
Operate Libreta with one founder supported by an internal team of AI agents rather than treating AI as a normal chatbot.

The founder communicates primarily with one lead agent: the **Chief of Staff**.

**Reason**
The goal is to use AI as operational leverage across fundraising, growth, partnerships, compliance, research, and eventually data/risk rather than repeatedly asking isolated questions.

**Evidence**
The company is being operated by one founder, while the work spans product, merchant acquisition, regulation, partnerships, fundraising, and future lending.

**Revisit when**
The company hires enough human employees that responsibilities and authority need to be redistributed.

---

## 2. Use one Chief of Staff as the founder-facing agent

**Decision**
The founder should primarily interact with a single **Chief of Staff / orchestrator agent**.

Specialist agents generally operate behind the scenes.

**Reason**
The founder should not have to manage ten separate AI conversations. The Chief of Staff should understand the objective, delegate work, inspect specialist responses, challenge weak conclusions, and return one coherent recommendation.

**Evidence**
The desired interaction is conversational: questions such as “What matters this week?”, “Prepare me for this investor meeting,” or “What is blocking the pilot?” should cause delegation automatically.

**Revisit when**
Certain specialist workflows become complex enough that direct founder-to-specialist interaction is clearly more efficient.

---

## 3. The Chief of Staff owns the final recommendation

**Decision**
Specialists provide analysis, but the Chief of Staff owns the final recommendation presented to the founder.

**Reason**
A collection of agents agreeing with one another is not useful. Someone in the system must reconcile disagreements, weigh evidence, and make the final recommendation.

**Evidence**
The desired architecture explicitly includes delegation, criticism, evidence review, and resolution of conflicting specialist conclusions.

**Revisit when**
Some decisions become sufficiently domain-specific that a human expert or dedicated specialist should own the final determination.

---

## 4. Build judgment into the workflow rather than relying on a clever prompt

**Decision**
Agent “judgment” will come from an explicit decision process:

request → objective → company facts → missing information → delegation → evidence → assumptions → comparison → Critic → additional research if needed → Chief of Staff recommendation → founder approval when required → action → record decision → evaluate result

**Reason**
Giving a powerful model a vague instruction to “make good decisions” is insufficient. The architecture itself should enforce better reasoning habits.

**Evidence**
The project requires agents to distinguish evidence from assumptions and to challenge one another before consequential recommendations reach the founder.

**Revisit when**
Operational data shows that parts of the workflow create unnecessary latency without improving decision quality.

---

## 5. Every agent must distinguish epistemic status

**Decision**
Agent outputs should distinguish:

- FACT
- ASSUMPTION
- INFERENCE
- RECOMMENDATION
- UNKNOWN

**Reason**
This reduces fabricated certainty and makes it clear which conclusions are grounded and which are hypotheses.

**Evidence**
The startup contains many unresolved questions, especially around regulation, underwriting, merchant behavior, and fundraising.

**Revisit when**
The schema proves too cumbersome in practice, while preserving the underlying distinction between evidence and speculation.

---

## 6. Use a Critic / Red Team agent

**Decision**
Include a dedicated Critic / Red Team specialist.

**Reason**
Its job is to challenge unsupported claims, premature conclusions, poor investor fit, bad growth assumptions, regulatory risk, and overpromising.

**Evidence**
Examples discussed include challenging whether acquisition is really the bottleneck, whether an investor actually fits the stage, and whether a legal assumption has been verified.

**Revisit when**
Evaluation shows that another architecture produces equivalent challenge without a dedicated critic.

---

## 7. Do not build all specialist agents immediately

**Decision**
Start with a small set of agents rather than building the entire proposed organization at once.

**Reason**
A smaller system is cheaper, easier to debug, easier to understand, and allows the orchestration pattern itself to be validated first.

**Evidence**
The long-term team contains fundraising, growth, partnerships, data, risk, legal, marketing, and critic roles, but most are not necessary for the first functional version.

**Revisit when**
A concrete recurring workload justifies adding a specialist.

---

# MILESTONE 1

## 8. Milestone 1 will be text-only

**Decision**
The first AI-team version will use text input/output only.

**Reason**
Voice adds interface complexity without proving whether the underlying orchestration is useful.

**Evidence**
The core unknown is whether a Chief of Staff coordinating specialists improves founder decisions.

**Revisit when**
The text orchestration works reliably.

---

## 9. Milestone 1 agents

**Decision**
Milestone 1 should contain:

1. Chief of Staff
2. Fundraising Research
3. Growth / Partnerships
4. Regulatory Research
5. Critic / Red Team

**Reason**
These roles map most closely to Libreta’s current operational problems while keeping the system small.

**Evidence**
Current bottlenecks include pilot validation, merchant retention, regulatory questions, partnerships, and eventually fundraising.

**Revisit when**
Milestone 1 is working and another specialist has a real job to perform.

---

## 10. Regulatory Research should exist early

**Decision**
Include a read-only Regulatory Research specialist in Milestone 1 rather than postponing all legal work until a later milestone.

**Reason**
Regulatory structure affects the pilot, lending, server architecture, data collection, and external messaging.

**Evidence**
The project itself describes regulatory understanding as a launch blocker.

**Revisit when**
Legal counsel establishes the relevant structure and the agent’s role shifts from research to ongoing monitoring.

---

## 11. Do not build Data/Underwriting in Milestone 1

**Decision**
The Data / Underwriting agent remains mostly later-stage.

**Reason**
Libreta v1 is local to the merchant device, and the company does not yet have sufficient centralized real-world data to validate underwriting.

**Evidence**
The first major evidence gap is merchant retention, not credit-model optimization.

**Revisit when**
Phase 2 provides centralized, consented merchant transaction data or a first lending cohort is being designed.

---

## 12. Do not build Fraud/Risk deeply in Milestone 1

**Decision**
Defer the full Fraud / Risk system until lending and centralized transaction data become relevant.

**Reason**
There is currently no active lending engine or centralized transaction stream for a fraud system to monitor.

**Evidence**
The current product-validation phase precedes lending.

**Revisit when**
The financing pilot is legally structured or Phase 2 data integrations begin.

---

# TECHNICAL ARCHITECTURE

## 13. Use Codex to build the software

**Decision**
Use Codex as the primary coding/development assistant for implementing the AI operating team.

**Reason**
Codex can inspect the repository, create files, implement architecture, run tests, and iterate on the codebase.

**Evidence**
The distinction established in this conversation is that Codex builds the system; it is not necessarily the runtime Chief of Staff itself.

**Revisit when**
Another development environment materially improves the engineering workflow.

---

## 14. Runtime agents will call LLM APIs

**Decision**
The agents inside the finished system will use LLM APIs at runtime.

**Reason**
There is no need to train proprietary language models from scratch. The product value is in orchestration, company context, tools, memory, permissions, and workflows.

**Evidence**
Existing APIs from OpenAI, Anthropic, Google, and others provide the underlying model intelligence.

**Revisit when**
Economics, privacy, latency, or scale make self-hosted models attractive.

---

## 15. Start runtime implementation with OpenAI

**Decision**
Implement the first runtime provider with OpenAI.

**Reason**
The OpenAI Agents SDK provides useful primitives for agents, tools, handoffs/orchestration, structured workflows, tracing, approvals, and eventual voice.

**Evidence**
It offers most of the plumbing needed for the intended architecture without requiring the project to invent an agent framework from scratch.

**Revisit when**
Benchmarking shows another provider materially improves a specific role.

---

## 16. Do not permanently couple agents to one model provider

**Decision**
Create a thin model/provider abstraction.

OpenAI will be implemented first, but orchestration logic should not assume every agent must always use OpenAI.

**Reason**
Different models may eventually be better for different roles in quality, cost, latency, tool use, or structured-output reliability.

**Evidence**
Potential future providers discussed include OpenAI, Anthropic/Claude, and Google/Gemini.

**Revisit when**
The abstraction starts adding complexity without any realistic second provider being tested.

---

## 17. Benchmark models by role later

**Decision**
Do not assume one model is best for every agent. Later, run the same representative tasks through different models and compare:

- reasoning quality
- tool use
- hallucination rate
- latency
- cost
- structured-output reliability

**Reason**
A strong Chief of Staff may justify a more capable model while repetitive specialist work may be cheaper on smaller models.

**Evidence**
“Benchmark and change” was defined as comparing models on the same tasks and switching based on measured performance rather than brand preference.

**Revisit when**
Enough real agent tasks exist to create a meaningful evaluation set.

---

## 18. Use Python \+ FastAPI for the AI team

**Decision**
Build the AI operating team backend primarily in Python with FastAPI.

**Reason**
Python has strong AI ecosystem support, while FastAPI provides a simple API boundary for the founder interface and later integrations.

**Evidence**
This stack was selected in the project architecture.

**Revisit when**
There is a compelling reason to consolidate around another backend stack.

---

## 19. Use Pydantic structured outputs

**Decision**
Use structured schemas rather than having agents return only free-form prose.

**Reason**
The Chief of Staff needs predictable fields for evidence, assumptions, unknowns, recommendations, and actions.

**Evidence**
A proposed Chief-of-Staff output includes objective, recommendation, evidence, assumptions, specialists consulted, alternatives, next actions, and decision status.

**Revisit when**
Actual usage reveals better schemas.

---

## 20. PostgreSQL comes after the first orchestration prototype

**Decision**
Do not require PostgreSQL for Milestone 1.

Add persistent company memory in Milestone 2.

**Reason**
The first question is whether routing/delegation/critique works. Persistence is unnecessary for proving that.

**Evidence**
The agreed build order separates basic orchestration from structured company memory.

**Revisit when**
Milestone 1 is functional.

---

## 21. Do not add pgvector initially

**Decision**
Use PostgreSQL first and introduce pgvector only if semantic retrieval becomes genuinely necessary.

**Reason**
Vector infrastructure should solve an observed retrieval problem rather than be included because agent systems commonly use it.

**Evidence**
The architecture explicitly prioritizes avoiding unnecessary infrastructure.

**Revisit when**
Company knowledge becomes large enough that ordinary structured retrieval is inadequate.

---

## 22. Do not add Redis, Celery, or background agents in Milestone 1

**Decision**
No Redis, Celery, autonomous schedules, or persistent background workers initially.

**Reason**
Milestone 1 is synchronous founder-request → orchestration → recommendation.

**Evidence**
Background autonomy does not help validate the core orchestration concept.

**Revisit when**
Recurring monitoring or asynchronous long-running work becomes a demonstrated need.

---

# REPOSITORY

## 23. Keep the existing Flutter app and AI team in the same repository but separated

**Decision**
Keep Libreta’s existing Flutter application at the repo root and create a separate:

`ai_team/`

directory for the internal founder AI system.

**Reason**
The two systems belong to the same company but have very different users and technical responsibilities.

**Evidence**
The existing repository already contains the Flutter app. Moving it would create unnecessary disruption.

**Revisit when**
The AI operating system becomes large enough to justify its own repository or independent deployment lifecycle.

---

## 24. Do not restructure the Flutter application for the AI team

**Decision**
The AI-team work must not move or unnecessarily modify existing Flutter directories such as `lib/`, `android/`, `assets/`, `test/`, or `pubspec.yaml`.

**Reason**
The founder AI system is an internal tool, not part of Libreta v1’s merchant runtime.

**Evidence**
Libreta v1 deliberately remains lightweight and device-local.

**Revisit when**
A deliberate product integration between Libreta and the AI backend becomes part of a later phase.

---

## 25. Keep the AI-team project brief in the repo

**Decision**
Store the permanent project context at:

`docs/AI_TEAM_PROJECT_BRIEF.md`

**Reason**
Codex and future agents should have a canonical description of the company, architecture, constraints, and agent roles.

**Evidence**
The file was created in the repository during this conversation.

**Revisit when**
Project documentation is reorganized.

---

## 26. Codex must plan before implementing Milestone 1

**Decision**
Before Codex writes the AI-team code, require it to produce an implementation plan covering architecture, files, dependencies, routing, schemas, Critic behavior, provider abstraction, tests, errors, tracing, and acceptance criteria.

**Reason**
This prevents a vague “build my AI company” prompt from causing Codex to invent unnecessary architecture.

**Evidence**
The agreed workflow is project brief → milestone specification → Codex plan → founder review → implementation.

**Revisit when**
Later changes are sufficiently small that a separate planning phase is unnecessary.

---

# LIBRETA PRODUCT

## 27. Libreta v1 remains device-local

**Decision**
For the merchant-facing v1, keep data on the device using SQLite.

No server, account, login, OTP, sync, Firebase, or Deuna/PayPhone integration in v1.

**Reason**
This keeps infrastructure minimal, allows offline operation, and gets the product into merchants’ hands faster.

**Evidence**
Target users may use low-end Android phones and have unreliable connectivity.

**Revisit when**
Merchants demonstrate sufficient retention to justify Phase 2.

---

## 28. The immediate wedge is the digital fiado notebook

**Decision**
The first reason merchants should repeatedly open Libreta is replacing the paper fiado notebook.

**Reason**
It solves an immediate existing problem before asking merchants to care about future credit.

**Evidence**
The product strategy identifies “who owes me what?” as the immediate pain point and retention hook.

**Revisit when**
Pilot behavior shows another feature is the stronger recurring value proposition.

---

## 29. Retention matters more than downloads

**Decision**
Evaluate the first product phase primarily through repeated merchant use, particularly day-7 and day-30 retention, rather than downloads.

**Reason**
Downloads do not show that Libreta becomes part of the merchant’s workflow.

**Evidence**
The company’s first major unknown is whether merchants continue using the digital fiado system.

**Revisit when**
Retention is established and acquisition economics become the next bottleneck.

---

# LEGAL / REGULATORY

## 30. Do not treat the current regulatory interpretation as settled law

**Decision**
The belief that device-local, non-lending v1 sits outside Ecuador’s lending regulatory perimeter is a **working legal hypothesis**, not a verified conclusion.

**Reason**
The AI system must not inherit an unverified legal interpretation as company fact.

**Evidence**
The project also requires Regulatory Research to determine exactly where applicable Ecuadorian financial rules begin to bind.

**Revisit when**
Qualified Ecuadorian counsel provides a written or otherwise reliable legal determination.

---

## 31. The Legal/Regulatory agent is not a lawyer

**Decision**
Use the Regulatory Research agent to research official sources, maintain a compliance matrix, identify unknowns, and prepare questions for counsel.

It must not substitute for qualified Ecuadorian legal advice.

**Reason**
Financial regulation, privacy, KYC/AML, lending structure, and promotional claims are high-consequence legal matters.

**Evidence**
The distinction between research assistance and legal determination was explicitly established.

**Revisit when**
Never for the principle; only the exact scope of what the agent may automate.

---

# PERMISSIONS

## 32. Agents may autonomously research and draft

**Decision**
Safe internal actions may be performed without founder approval, including:

- research
- analysis
- drafting
- planning
- summarization
- recommendations
- internal reports

**Reason**
These actions are reversible and are the primary source of leverage from the AI team.

**Evidence**
The project separates internal analytical work from consequential external actions.

**Revisit when**
An internal tool gains access to sensitive systems that warrant additional restrictions.

---

## 33. External/high-impact actions require founder approval

**Decision**
Initially require explicit founder approval before:

- investor outreach
- merchant outreach
- publishing content
- spending money
- changing production systems
- legally significant communications
- lending decisions
- underwriting-rule changes
- destructive actions

**Reason**
The agents should increase founder leverage without silently acquiring consequential authority.

**Evidence**
Human approval was identified as a core part of building judgment and safety into the system.

**Revisit when**
A narrowly defined action has repeatedly demonstrated enough reliability to safely automate.

---

# BUILDING IN PUBLIC / IP

## 34. Build in public around the problem and journey, not the proprietary playbook

**Decision**
Public content may discuss Libreta’s mission, merchant problem, founder journey, product progress, and lessons learned.

Do not publicly disclose important underwriting methodology, security architecture, sensitive data, or genuinely proprietary operational details.

**Reason**
Public building can create trust, distribution, and founder visibility without unnecessarily giving competitors a complete blueprint.

**Evidence**
The distinction established was effectively: **problem in public, playbook in private**.

**Revisit when**
Public disclosure becomes strategically useful or the supposedly proprietary information ceases to provide meaningful advantage.

---

## 35. Do not rely on ownership of the startup idea itself as protection

**Decision**
Do not assume the general concept of Libreta can simply be “licensed” or exclusively claimed.

Focus protection on actual IP and competitive assets such as:

- code
- brand/trademark
- proprietary data
- validated processes
- trade secrets
- potentially patentable inventions if applicable

**Reason**
The business concept itself is not equivalent to protectable proprietary implementation.

**Evidence**
The conversation distinguished ownership of an idea from copyright, trademark, patent, and trade-secret protection.

**Revisit when**
An IP attorney identifies a specific protectable invention or filing strategy.

---

# PILOT

## 36. Run a merchant pilot before serious investor outreach

**Decision**
Prioritize a real-world merchant pilot before making major investor outreach the company’s primary activity.

**Reason**
Real retention, transaction behavior, and repayment evidence would make the fundraising story substantially stronger than presenting only an app and a hypothesis.

**Evidence**
The current evidence gap is whether merchants actually use Libreta consistently.

**Revisit when**
Pilot execution requires capital or strategic relationships that make earlier investor/partner conversations necessary.

---

## 37. Expand the initial pilot concept to approximately 20 merchants with RUC

**Decision**
The working pilot concept is approximately **20 real Ecuadorian merchants with an active RUC**.

**Reason**
Twenty merchants is still operationally manageable for a founder while providing more behavioral diversity than a very small test.

**Evidence**
The founder proposed finding 20 merchants with RUC for a controlled 60-day test.

**Revisit when**
Recruitment difficulty, legal requirements, pilot costs, or experimental design justify a different cohort size.

---

## 38. Pilot duration: 60 days of merchant usage

**Decision**
The working pilot will ask merchants to use Libreta consistently for approximately **60 days**.

**Reason**
This is long enough to observe whether use becomes habitual rather than merely measuring initial curiosity.

**Evidence**
The proposed financing incentive is tied to completing a 60-day usage period.

**Revisit when**
Early pilot behavior demonstrates that a shorter or longer validation window provides better evidence.

---

## 39. Merchant income level should not determine pilot participation

**Decision**
For this first experimental cohort, do not require a high average income to participate.

**Reason**
The experiment is meant to observe real micro-merchant behavior across different business sizes, not select only merchants already likely to qualify for conventional credit.

**Evidence**
The founder explicitly wants participation to focus on consistent logging rather than average income.

**Revisit when**
Legal, affordability, responsible-lending, or partner requirements impose eligibility thresholds for the financing portion.

---

## 40. Do not reward meaningless daily entries

**Decision**
Pilot completion should measure **legitimate, consistent business use**, not merely whether a merchant entered at least one number every calendar day.

**Reason**
A strict streak requirement could encourage fake $1 entries or other gaming purely to preserve eligibility.

**Evidence**
The financing incentive creates a strong motivation to manufacture apparent activity if participation criteria are poorly designed.

**Revisit when**
Actual merchant behavior shows which participation metrics best distinguish genuine use from gaming.

---

## 41. Measure multiple retention checkpoints

**Decision**
Track at minimum:

- activation / Day 1
- Day 7
- Day 30
- Day 60 completion

Potentially also Day 14 and Day 45.

**Reason**
A single “completed 60 days” metric would hide when and why merchants stop using the product.

**Evidence**
Retention was already established as Libreta’s primary validation metric.

**Revisit when**
Pilot data identifies more useful engagement metrics.

---

## 42. Conduct direct merchant interviews during the pilot

**Decision**
Combine usage metrics with founder conversations/check-ins with merchants.

Suggested checkpoints include Day 0, Day 7, Day 30, and Day 60.

**Reason**
With only ~20 merchants, qualitative evidence can reveal why people stay, leave, fake activity, continue using paper, or value particular features.

**Evidence**
Small-cohort testing allows individual merchant behavior to be investigated rather than hidden inside aggregates.

**Revisit when**
The merchant base becomes too large for founder-led interviews.

---

## 43. Explicitly measure whether merchants would continue without the incentive

**Decision**
Ask merchants whether they would continue using Libreta if the $200 financing incentive did not exist, and measure continued usage after the incentive phase.

**Reason**
Otherwise high retention may prove only that people are willing to use an app in exchange for access to money.

**Evidence**
The $200 incentive substantially changes merchant motivation during Days 1–60.

**Revisit when**
Post-incentive retention data provides a stronger behavioral answer than survey responses.

---

# $200 FINANCING EXPERIMENT

## 44. Working incentive: $200 financing after successful pilot completion

**Decision**
The current experimental concept is that merchants who legitimately complete the 60-day pilot become eligible for **$200 in financing**.

**Reason**
A meaningful economic incentive may motivate consistent participation while remaining small enough for a controlled first cohort.

**Evidence**
Twenty $200 financing amounts would represent a maximum of approximately **$4,000 in principal** if all 20 qualify.

**Revisit when**
Legal counsel, a lending partner, affordability analysis, pilot economics, or responsible-lending requirements indicate a different structure or amount.

---

## 45. The $200 financing is not yet an unconditional public guarantee

**Decision**
Do **not** currently advertise:

> “Use Libreta for 60 days and Libreta guarantees you a $200 loan.”

Treat the financing as a proposed pilot incentive pending legal and structural validation.

**Reason**
It has not yet been established that Libreta may legally originate, promise, or advertise credit directly in Ecuador.

**Evidence**
The regulatory structure for lending remains unresolved.

**Revisit when**
Qualified Ecuadorian counsel and/or an authorized lending partner confirms exactly what can legally be offered and how it may be communicated.

---

## 46. Prefer an authorized lending structure if required

**Decision**
Investigate whether the $200 financing should be originated by a licensed bank, cooperative, MFI, fintech, or other authorized lending partner rather than directly by Libreta.

**Reason**
This may allow Libreta to test its product/data thesis without prematurely becoming a regulated lender.

**Evidence**
The legal structure for direct Libreta lending is unresolved and is one of the most important pre-pilot questions.

**Revisit when**
Regulatory research and Ecuadorian counsel establish the permissible options.

---

## 47. Proposed repayment window: approximately 60 days

**Decision**
The working experiment proposes that the $200 financing be repaid over approximately **60 days**.

**Reason**
This creates a short first repayment cohort that can produce observable repayment behavior without introducing long-duration credit exposure.

**Evidence**
The founder proposed a $200 amount repayable over 60 days.

**Revisit when**
Responsible affordability analysis, lending-partner requirements, merchant cash flow, or legal rules indicate a more appropriate term.

---

## 48. The first uniform $200 cohort is an experiment, not the future underwriting policy

**Decision**
Giving qualifying pilot merchants the same $200 amount should not be interpreted as the permanent Libreta credit policy.

**Reason**
The first cohort is intended to learn about behavior and repayment, not to establish that merchants with different economics deserve identical credit limits.

**Evidence**
The eventual underwriting system is supposed to be learned and validated from evidence rather than assumed in advance.

**Revisit when**
Enough real repayment data exists to test differentiated credit limits.

---

## 49. Do not assume a proposed underwriting formula is valid

**Decision**
Any formula such as:

`max_loan \= min(30% of 90-day total revenue, 8 × average daily digital revenue)`

is a **hypothesis**, not approved underwriting policy.

**Reason**
There is currently no empirical evidence establishing that those weights or limits predict repayment responsibly.

**Evidence**
The project explicitly states that no proposed scoring formula should be assumed correct.

**Revisit when**
Sufficient historical transaction and repayment data exists for validation.

---

# PILOT EVIDENCE / FUNDRAISING

## 50. The pilot should generate evidence before a larger raise

**Decision**
Use the pilot to produce real evidence that can later strengthen investor outreach.

Potential evidence includes:

- merchants recruited
- Day-7 retention
- Day-30 retention
- Day-60 completion
- transaction/logging consistency
- merchant interviews
- post-incentive retention
- financing uptake
- repayment behavior

**Reason**
Investors can evaluate real merchant behavior much more seriously than an untested product thesis.

**Evidence**
A story such as “20 merchants joined, X remained after 60 days, and Y repaid the first financing cohort” is materially stronger than “we built an app.”

**Revisit when**
A strategic investor or partner provides a reason to begin conversations before the complete pilot finishes.

---

## 51. Do not claim that a 20-merchant cohort validates the underwriting model statistically

**Decision**
Treat the first 20 merchants as exploratory evidence, not statistical proof of a credit-scoring model.

**Reason**
The cohort is too small to establish robust predictive relationships.

**Evidence**
The pilot can reveal patterns and operational feasibility, but not establish production-grade underwriting accuracy.

**Revisit when**
A substantially larger dataset with repayment outcomes becomes available.

---

## 52. Separate the first pilot questions from future underwriting questions

**Decision**
The experiment should answer questions in sequence:

1. Can we recruit the right merchants?
2. Will they actually use Libreta?
3. What does their real business behavior look like?
4. What happens when a controlled small financing cohort is introduced?
5. Later: can historical behavior reliably predict repayment?

**Reason**
Trying to answer all of these at once risks claiming a credit model before product usage itself has been validated.

**Evidence**
Libreta is currently in product-validation stage.

**Revisit when**
The earlier questions have produced sufficient evidence to move to the next stage.

---

# FUNDRAISING

## 53. Treat $200,000 as a hypothesis, not a predetermined fundraising target

**Decision**
Do not automatically assume Libreta should raise exactly $200,000.

**Reason**
The amount should follow from milestones, runway, legal costs, pilot operations, infrastructure, and whether lending capital belongs in the equity raise.

**Evidence**
The project brief explicitly reframed $200k as an amount to validate rather than a fixed requirement.

**Revisit when**
A proper use-of-funds and runway model exists.

---

## 54. Fundraising should be framed around de-risking milestones

**Decision**
When fundraising begins seriously, frame the raise around what the money proves rather than merely what expenses it pays.

Working progression:

capital
→ merchant pilot
→ retention evidence
→ Phase 2 infrastructure/integrations
→ verified transaction history
→ first controlled financing cohort
→ repayment evidence
→ underwriting validation
→ next financing stage

**Reason**
Investors fund progress toward reduced risk and stronger evidence.

**Evidence**
The startup currently has a product hypothesis but limited real-world behavioral evidence.

**Revisit when**
Pilot outcomes change the company’s most important risk.

---

# FUTURE MEMORY

## 55. Company memory should eventually be structured, not merely conversation history

**Decision**
When persistence is implemented, store important company state explicitly in PostgreSQL.

Potential categories include:

- goals
- decisions
- reasons
- assumptions
- experiments
- metrics
- investor interactions
- partnership interactions
- legal questions
- compliance status
- tasks
- outcomes
- founder approvals

**Reason**
The Chief of Staff must be able to answer “Why did we decide this?” using the actual historical reason rather than model recollection.

**Evidence**
Conversation memory alone is insufficient for an operational company system.

**Revisit when**
Designing Milestone 2.

---

## 56. Separate company state from company doctrine

**Decision**
Future memory should distinguish changing operational state from relatively stable company rules/policies.

Examples:

**State**
- merchants onboarded
- pilot retention
- investor pipeline
- current blockers

**Doctrine**
- fiado issued is not income
- no consequential external action without approval
- retention outranks downloads during validation

**Reason**
These have different update patterns and authority levels.

**Evidence**
The project already contains both live metrics and durable operating rules.

**Revisit when**
Designing the Postgres schema in Milestone 2.
