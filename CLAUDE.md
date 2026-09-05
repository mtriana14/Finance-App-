# Libreta — working notes for Claude

Ventas, fiado e historial para comerciantes del Ecuador. A digital replacement
for the paper notebook a tienda owner keeps behind the counter.

Read this before touching anything.

---

## Invariants

These are not preferences. Breaking one produces a number a merchant will act
on that is wrong, or a rewrite later.

All eight hold as of the commit that added this line. Each was checked against
the code, not assumed — see the *Verified* notes.

### 1. Money is `int` cents, never `double`. Division only at display.

A `double` cannot hold 0.1. Every amount — column, field, parameter, return —
is integer cents. `Money.format` renders by integer division and string
padding, not by `cents / 100`.

*Verified:* the only float division in the app is chart bar geometry in
`week_chart.dart`. `money.dart` contains no `double` except `percent()`, which
takes a ratio, not an amount.

### 2. Timestamps stored UTC, grouped by LOCAL day.

Ecuador is UTC-5 with no DST, which makes it tempting to conflate the two. They
are not the same. `occurred_at` is a drift `dateTime` column, stored as a unix
epoch — an absolute instant. The *day* a sale belongs to is a separate
`business_day` integer (`yyyymmdd`), computed from local time when the row is
written. Grouping, the dashboard's "today" and the end-of-day close all key off
`business_day`, never off the timestamp.

Never group by formatting a timestamp in SQL. Never compare instants to decide
what day something happened on.

### 3. One `ledger_entries` table with a `LedgerKind` enum.

Every movement of money is one row: `cashSale`, `qrSale`, `cardSale`,
`fiadoIssued`, `fiadoPayment`. No separate sales table, no separate payments
table. This is what makes Historial a single query and gives "is this income?"
exactly one home.

The enum index is persisted. Values may only ever be **appended**.

*Naming:* the invariant as originally written said an `entries` table and an
`EntryKind` enum. The code says `ledger_entries` and `LedgerKind`. Same
structure, different names — the names above are the real ones.

### 4. `fiadoIssued` is never income. Filter by an inclusion list.

A fiado issued is money lent out, not money earned. It appears in Historial for
visibility and is excluded from every total.

Test income with an **inclusion list of income kinds**, never `!= fiadoIssued`.
The exclusion form silently counts the next kind anyone adds — a refund, an
adjustment, a chargeback — as revenue.

*Verified:* `incomeKinds` in `ledger_kind.dart` names the four, and
`isIncome` is `incomeKinds.contains(this)`. A test asserts the set and pins
`LedgerKind.values.length`, so appending a kind fails the suite until somebody
decides whether it is revenue.

The daily total is built the same way: `LedgerMath.totals` switches
exhaustively over every kind into a named bucket, and `totalCents` sums the
four income buckets by name.

### 5. Debt totals come from one query, read in three places.

`fiadoEntriesProvider` → `LedgerMath.balances` feeds all three:

| Where | Provider |
|---|---|
| Dashboard "Te deben" | `outstandingTotalProvider` |
| Libreta "Total pendiente" | `outstandingTotalProvider` |
| Customer balance | `customerBalanceProvider` |

Never cache a debt total separately, never recompute one from a different
source. Three numbers that agree today because someone was careful will
disagree the first time a payment path changes.

### 6. Never delete a ledger row. Void it with `voidedReason`.

A merchant arguing with a customer about a debt needs the history, including
the correction. Deleting the row destroys the evidence that the correction
happened — and a debt that can vanish without a trace is worth less than the
paper notebook this replaces.

`LedgerRepository.voidEntry(id, reason:)` stamps `voided_at` / `voided_reason`
and touches nothing else. The row keeps its place in the customer's statement,
struck through with the reason, and stops counting everywhere:
`LedgerEntry.countsInTotals` is the single test, used by `LedgerMath.totals`,
`balances` and `statement`. The 24-hour correction window still applies, and an
entry cannot be voided twice.

The one real `DELETE` left is `deleteAll()`, behind "borrar todos mis datos" in
Perfil. That is the merchant erasing their own data, not correcting an entry.

*Verified:* `voided` appears in the schema, the repository, both screens and the
CSV. A migration test builds a real v1 database on disk and opens the current
schema over it.

### 7. No emoji in the UI. Stroke icons only.

Emoji render differently on every Android skin, break at small sizes, and read
as unserious in a product that handles money. Every glyph comes from the single
sprite in `core/widgets/app_icon.dart`: stroke paths on a 24-unit grid, 1.7–1.9
width, `currentColor`, drawn by `CustomPainter`. No Material `Icons.*`.

This governs *in-app* icons. It does not govern the launcher icon, which is
solid-filled by necessity — see `tools/make_branding.py`.

### 8. Spanish only, es-EC.

No English in the UI, no untranslated placeholders. `Locale('es')`, dates
through `core/format/dates.dart`.

The one deliberate exception: `Money` builds its number pattern on `en_US`, to
force `$1,234.56` with a decimal **point**. `es_EC` would render a comma. This
is a formatting decision about USD, not a language leak.

---

## Stack

**v1 runtime — these only.**

| | |
|---|---|
| Framework | Flutter |
| State | Riverpod |
| Database | drift (SQLite) |
| Charts | fl_chart |
| Formatting | intl (es-EC dates, USD) |

Plus `path_provider` and `share_plus`, which the required CSV and WhatsApp
exports cannot work without. Both are local-only.

**dev_dependencies** (build-time, not in the APK): `drift_dev`,
`build_runner`, `flutter_lints`, `flutter_launcher_icons`,
`flutter_native_splash`.

**Ask before adding any package.** Nothing from the Phase 2 list — dio,
firebase, secure_storage, sqlcipher — belongs in v1.

Architecture is `core / domain / data / presentation`. All arithmetic lives in
pure functions in `domain/services/ledger_math.dart`, over plain models, so the
money rules are testable without a database. Repositories query rows and let
`LedgerMath` decide what they mean.

---

## Scope

**v1 has no server.** No accounts, no login, no OTP, no sync, no Firebase.
Everything is local SQLite. This is deliberate: it costs nothing to run, works
in a market stall with no signal, and keeps the product outside the lending
perimeter of Resolution JPRF-F-2023-076, which binds when you *lend*, not when
you give away a digital notebook.

Shipped: Libreta (05–07), Dashboard (03), Cash Log (04), Historial (08),
Perfil (12).

Not in v1: onboarding and setup (01–02), Connected Accounts (14), all of Mi
Crédito (09–11), Notifications (13), and every sync behaviour. The bottom nav
has four tabs, not the spec's five — a Crédito tab that leads nowhere is worse
than no tab. `qrSale` and `cardSale` have no producer yet; the schema is ready
for the Deuna and PayPhone sync without a migration.

Data lives on one device with no backup. Perfil says so plainly and pushes CSV
export. Do not let this reach twenty merchants without a backup story, and do
not ship past the pilot without SQLCipher.

---

## Working rules

- **One screen per session.** Finish it, don't half-build three.
- **Tests ship with the feature**, not after. A test that would also pass
  against the broken code proves nothing — check that it fails first.
- **Commit when it works.** `flutter analyze` clean and `flutter test` green
  before committing, every time.
- **Announce before touching money, dates or totals.** Say what you are about
  to change and why, before changing it. These are the four files where a
  quiet mistake reaches a merchant's pocket: `core/format/money.dart`,
  `core/format/dates.dart`, `domain/services/ledger_math.dart`,
  `data/repositories/ledger_repository.dart`.

## Commands

```bash
flutter pub get
dart run build_runner build     # only after changing the drift schema
flutter test
flutter analyze
flutter run
```

Generated drift code (`*.g.dart`) is committed, so the project builds without
running the generator first.

## Schema

Currently version 2. Every bump needs a branch in `onUpgrade` *and* a test in
`test/migration_test.dart` that builds the previous schema by hand and opens
the current one over it. A migration that drops a column does not throw
anything a merchant would notice — it just loses the record of who owes them
money.
