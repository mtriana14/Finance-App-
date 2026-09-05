# Build Sessions — copy these one at a time

Repo layout before you start:

```
libreta_app/
├── CLAUDE.md                 ← auto-read every session. Never paste it.
├── docs/
│   ├── design-spec.md        ← the 14-screen spec (app-design-prompt.md, renamed)
│   └── wireframes.html       ← visual reference, Claude Code can read it
├── lib/
│   ├── data/                 ← drift tables, DAOs
│   ├── domain/               ← models, money math, business rules
│   └── presentation/         ← screens, widgets, theme
└── test/
```

**The rule:** one session per block below. `/clear` between them. Commit when it works.
Start each session in **plan mode** (Shift+Tab twice) — read the plan, correct it, then let it write.

**The anti-pattern:** pasting the whole spec, or saying "build the app". Both produce
code that looks fine per-screen and contradicts itself across screens.

---

## 0 — Scaffold (you, not Claude)

```powershell
flutter create --org ec.tunegocio --platforms android libreta_app
cd libreta_app
git init && git add -A && git commit -m "flutter scaffold"
```
Drop `CLAUDE.md` in the root and the two docs in `docs/`. Commit again.

---

## 1 — Data layer

> Read CLAUDE.md. Create `lib/data/tables.dart` with the `Customers` and `Entries`
> tables exactly as specified in the Invariants section — money as int cents,
> `occurredAt` in UTC, the `EntryKind` enum, and the `voidedReason` column.
> Set up the drift database class in `lib/data/database.dart` and run build_runner.
>
> Then create `lib/data/ledger_dao.dart` with: `addSale`, `addFiado`, `addPayment`,
> `balanceFor(customerId)`, `totalOwed()`, `salesTodayCents()`, and
> `customersWithBalances()`.
>
> No UI in this session. Stop after `flutter analyze` passes clean.

---

## 2 — Tests (do NOT skip this one)

> Read CLAUDE.md. Write tests in `test/ledger_test.dart` against `LedgerDao` using an
> in-memory drift database. Cover:
>
> 1. fiado $15 then payment $10 leaves a balance of $5
> 2. a fiado issued does NOT count toward `salesTodayCents()`
> 3. a fiado payment DOES count toward `salesTodayCents()`
> 4. `totalOwed()` equals the sum of every customer's `balanceFor()`
> 5. a row with `voidedReason` set is excluded from all totals
> 6. a sale at 20:00 Guayaquil time lands in *that* local day, not the next
>
> Test 6 is the one that catches the timezone bug. Make sure it actually fails if
> day boundaries are computed in UTC.

These six tests are your contract. Every later session runs them. When one breaks,
something drifted — that's the whole point.

---

## 3 — Theme and money formatting

> Read `docs/design-spec.md` § DESIGN SYSTEM and look at `docs/wireframes.html` for
> the visual language. Create `lib/presentation/theme/` with color tokens, text
> styles, and spacing constants.
>
> Also create `lib/domain/money.dart` — a single formatter for int cents to es-EC
> display (`$1,234.50`). Every screen uses this one function; no ad-hoc formatting
> anywhere.
>
> Icons are stroke SVGs, never emoji. Set up `flutter_svg` if needed and add one
> icon sprite file.

---

## 4 — Libreta: customer list

> Read `docs/design-spec.md` § SCREEN 05. Build the Libreta customer list at
> `lib/presentation/libreta/libreta_screen.dart`.
>
> Data comes from `LedgerDao.customersWithBalances()` via a Riverpod provider —
> reactive, so it updates when entries change. Sort by highest debt. Two-letter
> monogram avatars with a deterministic color from the name hash. Red styling for
> debts over 30 days. Empty state per spec.
>
> The FAB should exist but do nothing yet.

---

## 5 — Libreta: new fiado

> Read § SCREEN 06. Build the new fiado flow. Customer picker (recents + search +
> "nuevo cliente"), amount entry with the preset grid where taps ADD, optional note
> capped at 80 chars, confirmation card showing the resulting balance.
>
> Per spec: back button at each step preserving input, X close with a discard
> confirmation. Wire the Libreta FAB to this.

---

## 6 — Libreta: customer detail + record payment

> Read § SCREEN 07. Build the customer detail screen with the movement list showing
> a running balance beside each entry, newest first, paginated at 30.
>
> "Registrar pago" pre-fills the full balance and accepts any amount up to it.
> Partial payments show what remains.
>
> Critical per CLAUDE.md invariant 5: recording a payment must update the customer
> balance, the Libreta total, and the Dashboard "Te deben" from the same query.
> Do not cache any of them separately.

---

## 7 — Checkpoint review (no new code)

> Read § VERIFICATION CHECKPOINT 05, 06 and 07 in `docs/design-spec.md`. Go through
> the implementation and check every single line item. Report which pass, which fail,
> and which are ambiguous.
>
> Do not fix anything in this session — just the report.

Then fix them in a following session, one at a time. **Ship this to one merchant now**,
even though there's no dashboard yet. The libreta alone is useful.

---

## 8 — Dashboard

> Read § SCREEN 03. Build the dashboard. Hero total, the 4-category breakdown that
> must sum to it, the segmented split bar, 7-day chart with fl_chart, quick action
> buttons, "Te deben" card, and the day-one zero state.
>
> All figures from `LedgerDao` — no hardcoded numbers anywhere, including in the
> zero state.

---

## 9 — Cash log

> Read § SCREEN 04. Build the cash log: preset grid where taps add, custom amount
> with a numeric keypad, note field, and the "cierre del día" mode.
>
> The end-of-day reconciliation VOIDS individual cash entries for that day
> (sets `voidedReason`) rather than deleting or adding. Show the warning first.
> Test 5 already covers the void behavior — make sure it still passes.

---

## 10 — Historial

> Read § SCREEN 08. Build the transaction history: filter chips, day grouping with
> per-day totals, virtual scrolling.
>
> Fiados issued appear in the list but are excluded from day totals and rendered
> muted. Verify the sample day in the spec reconciles: the rows must sum to $127.50
> and match the dashboard breakdown.

---

## Every few sessions

> Run `flutter test` and `flutter analyze`. Then re-read CLAUDE.md and check the
> codebase against all 8 invariants. Report any violation you find, including in
> code you wrote earlier.

This is the drift check. Run it before every merchant build.
