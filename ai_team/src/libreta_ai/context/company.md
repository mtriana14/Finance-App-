# Libreta runtime company context

> `DECISIONS.md` is authoritative. This file is only a curated runtime snapshot for the AI team. If this snapshot, a prompt, the project brief, or another document conflicts with `DECISIONS.md`, `DECISIONS.md` wins. Update this snapshot manually when approved decisions change.

## Confirmed company facts

- Libreta is a device-local Flutter application for small merchants in Ecuador to record business activity, including cash sales, fiado balances and repayments, and customer-ledger activity. [Source: `DECISIONS.md` §§7, 17]
- The Milestone 1 AI team is an internal founder tool, isolated from the Flutter application. It has one Chief of Staff, three specialists, and one Critic. [Source: `DECISIONS.md` §§1, 11, 48]
- Milestone 1 is synchronous and text-only. It has no PostgreSQL, Redis, Celery, background jobs, persistent memory, or autonomous external actions. [Source: `DECISIONS.md` §§24, 25, 41]

## Accepted doctrine

- Optimize for retained, legitimate merchant use rather than downloads or manufactured activity. [Source: `DECISIONS.md` §§19, 43]
- Separate FACT, ASSUMPTION, INFERENCE, RECOMMENDATION, and UNKNOWN. Facts need evidence; unresolved questions stay unresolved. [Source: `DECISIONS.md` §§5, 6]
- The Chief of Staff owns the final recommendation. Specialists provide bounded analysis; the Critic tests material claims and may pass sound work. [Source: `DECISIONS.md` §§2, 8]

## Current pilot working plan

- Recruit approximately 20 Ecuadorian merchants with an active RUC and real operating businesses for roughly 60 days of legitimate product use. [Source: `DECISIONS.md` §42; `docs/PILOT_60_DAY.md`]
- Track activation and retention, especially Day 7, Day 30, and Day 60, plus honest transaction and fiado-ledger usage. Conduct merchant check-ins around Day 0, Day 7, Day 30, and Day 60. [Source: `DECISIONS.md` §§42, 43; `docs/PILOT_60_DAY.md`]
- A proposed working experiment would make qualifying participants eligible for $200 in financing, with repayment observed for approximately 60 days. It is not an unconditional promise. [Source: `DECISIONS.md` §§45, 46; `docs/PILOT_60_DAY.md`]
- With this small cohort, inspect individual merchant behavior and post-incentive retention rather than treating percentages as conclusive proof. [Source: `docs/PILOT_60_DAY.md`]

## Explicit hypotheses and unresolved questions

- UNKNOWN: whether Libreta may legally offer, advertise, originate, or promise the proposed financing in Ecuador. [Source: `DECISIONS.md` §§26, 45, 46]
- UNKNOWN: whether a licensed lending partner is required and what structure that partnership must use. [Source: `DECISIONS.md` §§27, 45]
- UNKNOWN: the applicable regulatory perimeter, including lending, privacy, KYC/AML, promotional language, and partner obligations. Local device storage does not by itself settle that perimeter. [Source: `DECISIONS.md` §§26, 28]
- ASSUMPTION: a lawful $200 pilot-financing experiment with approximately 60-day repayment can be designed. [Source: `DECISIONS.md` §§45, 46]
- ASSUMPTION: an underwriting formula can eventually be developed from responsible signals. No formula is approved today. [Source: `DECISIONS.md` §44]
- ASSUMPTION: product behavior may help predict repayment. The first cohort must test this; it cannot establish statistical validity. [Source: `DECISIONS.md` §§43, 44; `docs/PILOT_60_DAY.md`]
- A cohort of about 20 merchants is exploratory only and cannot validate a production lending or underwriting model. [Source: `docs/PILOT_60_DAY.md`]

## Permissions and action boundaries

- The AI team may perform internal analysis, research synthesis, planning, and drafting. [Source: `DECISIONS.md` §§33, 35]
- Founder approval is required before outreach, publishing, spending, production changes, lending or underwriting actions, legal communications, destructive actions, or any other external commitment. [Source: `DECISIONS.md` §§34-37]
- Regulatory analysis is informational support, not legal advice. Escalate legal conclusions and merchant-facing financing language to qualified Ecuadorian counsel. [Source: `DECISIONS.md` §§26, 28]

## Source references

- `DECISIONS.md` — authoritative record for approved decisions and conflict resolution.
- `docs/PILOT_60_DAY.md` — working, pre-funding pilot plan; not approved policy.
- `docs/AI_TEAM_PROJECT_BRIEF.md` — background brief only; superseded wherever it conflicts with `DECISIONS.md`.
