# Libreta

Una app para comerciantes del Ecuador: registra ventas en efectivo, lleva el
fiado de tus clientes y mira tu historial — todo en el teléfono, sin internet.

This is **v1** of the merchant data-to-lending app described in the design spec:
the free tools half, built to be used daily before any lending exists.

## What v1 is

v1 has **no server**. No accounts, no login, no OTP, no sync, no Firebase.
Everything lives in local SQLite on the device. That is deliberate — it costs
nothing to run, works in a market stall with no signal, and keeps the product
outside the lending perimeter of Resolution JPRF-F-2023-076, which binds when
you *lend*, not when you give away a digital notebook.

Built in the spec's stated order — Libreta first, because retention is the
binding constraint, not build dependency:

| Screen | Spec | What it does |
|---|---|---|
| Libreta | 05 | Customers who owe you, biggest debt first |
| Nuevo fiado | 06 | Log a fiado in ~4 taps |
| Detalle del cliente | 07 | Full statement, running balance, partial payments |
| Inicio | 03 | Today's sales, the four-channel breakdown, 7-day chart |
| Registrar venta | 04 | Quick-tap cash entry, plus end-of-day reconciliation |
| Historial | 08 | Every movement, filterable, CSV / WhatsApp export |
| Perfil | 12 | Cash float, quick amounts, dark mode, export, delete |

**Not in v1**, exactly as the spec scopes it: onboarding and account setup
(01–02), Connected Accounts (14), all of Mi Crédito (09–11), Notifications (13),
and every sync behaviour. Those screens are fully specified in the design doc
because they are the finished product — not what ships in week 6.

## The one rule everything rests on

```
Ventas del día = QR + Tarjeta + Efectivo + Cobros de fiado
```

A **fiado issued is not income** — it is money lent out. Only fiado *payments
received* count. The dashboard's four breakdown figures are computed in the same
pass as the hero number, so they cannot disagree with it.

Two guards protect that total from being counted twice:

- **Fiado paid in cash.** Recorded once, on the customer's page. If a matching
  amount is about to be logged again as a plain cash sale within five minutes,
  the app asks before saving.
- **End of day.** The `Cierre del día` **replaces** the day's individual cash
  entries rather than adding to them. Replaced rows are kept, greyed out, in
  Historial — an audit trail, not a delete.

Debt aging is FIFO: payments settle the oldest fiado first, so the red
"overdue" state reflects how old the *outstanding money* is, not how long the
customer has had an account.

## Architecture

```
lib/
  core/         theme tokens, es-EC money & date formatting, shared widgets
  domain/       plain models + LedgerMath — every total, no database
  data/         drift schema, repositories, Riverpod providers
  presentation/ screens
```

One **ledger table** holds every movement (`cashSale`, `qrSale`, `cardSale`,
`fiadoIssued`, `fiadoPayment`). That is what makes Historial a single query and
gives the "does this count as income?" question exactly one home.

Queries return *everything*, including entries a day-close replaced, and leave
the counting decision to `LedgerMath`. Historial needs to show a replaced row;
the dashboard needs to ignore it; both read the same rows. `qrSale` and
`cardSale` have no producer in v1 — the schema is ready for the Phase 2 Deuna
and PayPhone sync without a migration.

Historial pages by **day**, not by row. A merchant with three years of trading
has tens of thousands of entries and none of the off-screen ones belong in
memory; paging by row instead would cut a day in half at the page boundary and
print a section total for a day it had only partly loaded. Filters and date
ranges are applied in SQL, so they narrow the days as well as the rows.

All the arithmetic lives in pure functions over plain models, so the spec's
integrity checklists are directly testable without a database.

## Running it

```bash
flutter pub get
dart run build_runner build   # only after changing the drift schema
flutter run
flutter test
```

Generated drift code (`*.g.dart`) is committed so the project builds without
running the generator first.

## Tests

50 tests, all passing:

- `test/ledger_math_test.dart` — the business rules, including the worked day
  from spec Screen 08 reconciling to `$127.50` against the Screen 03 breakdown.
- `test/ledger_repository_test.dart` — real SQLite: day-close replacement,
  fiado round trips, the 24-hour correction window, cascade deletes, and
  Historial paging including the boundary day arriving whole.
- `test/widget_test.dart` — the real screens against an in-memory database,
  including layout passes over every tab at 360x640 and at the largest font
  scale the app honours.

## Where this departs from the spec

1. **`minSdk` is 24, not 21.** Flutter 3.47 has dropped Android 5.0; the build
   fails below 24 (Android 7.0, 2016). Pinned explicitly in
   `android/app/build.gradle.kts` so the gap is visible. Worth a look at what
   the target merchants actually carry before the pilot.
2. **Four tabs, not five.** `Crédito` is out of v1 scope by the spec's own
   build plan, and a tab that leads nowhere is worse than no tab. The nav is
   built so the fifth slot drops in without rework.
3. **Two packages beyond the listed v1 stack**: `path_provider` and
   `share_plus`. The spec requires CSV export and a WhatsApp-shareable summary;
   neither is reachable without them. Both are local-only — no server, no
   network. Nothing from the Phase 2 list was installed.
4. **Inter and JetBrains Mono are bundled** as OFL-licensed variable fonts
   (`assets/fonts/`, ~1MB) rather than fetched at runtime, because the app has
   to look right offline. Licences ship alongside them.
5. **The APK has not been built.** The environment this was written in blocks
   `dl.google.com`, so neither the Android SDK nor Gradle's AndroidX artifacts
   could be fetched. Dart analysis is clean and all 42 tests pass, but
   `flutter build apk` is unrun — do that first on a real machine.

## Before the pilot

- Build and hand-install the APK on 10 phones; `--split-per-abi` keeps each
  around 8MB.
- Add a real signing config — release currently signs with debug keys.
- v1 keeps data on one device only. Perfil says so plainly and pushes CSV
  export; the app should not reach 20 merchants without a backup story.
- What you are measuring is day-7 and day-30 retention, not downloads.
