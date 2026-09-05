import 'package:flutter_test/flutter_test.dart';
import 'package:libreta/core/format/money.dart';
import 'package:libreta/domain/models/customer.dart';
import 'package:libreta/domain/models/ledger_entry.dart';
import 'package:libreta/domain/models/ledger_kind.dart';
import 'package:libreta/domain/services/ledger_math.dart';

/// These tests are the spec's "Business Logic Integrity" and "Data Integrity"
/// checklists, written down as assertions.

var _nextId = 0;

LedgerEntry entry(
  LedgerKind kind,
  int cents, {
  DateTime? at,
  int? customerId,
  String? note,
  bool superseded = false,
  DateTime? createdAt,
  DateTime? voidedAt,
  String? voidedReason,
}) {
  final when = at ?? DateTime(2026, 9, 2, 12);
  return LedgerEntry(
    id: ++_nextId,
    kind: kind,
    amountCents: cents,
    occurredAt: when,
    customerId: customerId,
    note: note,
    supersededByCloseout: superseded,
    voidedAt: voidedAt,
    voidedReason: voidedReason,
    createdAt: createdAt ?? when,
  );
}

Customer customer(int id, String name) =>
    Customer(id: id, name: name, createdAt: DateTime(2026, 1, 1));

void main() {
  group('Dashboard total', () {
    // The exact day laid out in Screen 08 of the spec, which is stated there to
    // reconcile against the Screen 03 breakdown.
    final specDay = [
      entry(LedgerKind.qrSale, 2500, at: DateTime(2026, 9, 2, 15, 10)),
      entry(LedgerKind.cashSale, 2250,
          at: DateTime(2026, 9, 2, 14, 32), note: 'almuerzos y bebidas'),
      entry(LedgerKind.qrSale, 2000, at: DateTime(2026, 9, 2, 13, 10)),
      entry(LedgerKind.cardSale, 3250, at: DateTime(2026, 9, 2, 11, 45)),
      entry(LedgerKind.cashSale, 1250, at: DateTime(2026, 9, 2, 10, 20), note: 'pan, huevos'),
      entry(LedgerKind.fiadoIssued, 1500, at: DateTime(2026, 9, 2, 9, 5), customerId: 1),
      entry(LedgerKind.fiadoPayment, 1500, at: DateTime(2026, 9, 2, 8, 30), customerId: 2),
    ];

    test('equals QR + tarjeta + efectivo + cobros de fiado', () {
      final t = LedgerMath.totals(specDay);
      expect(t.qrCents, 4500);
      expect(t.cardCents, 3250);
      expect(t.cashCents, 3500);
      expect(t.fiadoCollectedCents, 1500);
      expect(t.totalCents, 12750);
      expect(Money.format(t.totalCents), r'$127.50');
    });

    test('breakdown sums exactly to the hero number', () {
      final t = LedgerMath.totals(specDay);
      final sum = SalesChannel.values.fold(0, (acc, ch) => acc + t.centsFor(ch));
      expect(sum, t.totalCents);
    });

    test('a fiado issued is money lent, never income', () {
      final t = LedgerMath.totals(specDay);
      expect(t.fiadoIssuedCents, 1500);
      // Present for visibility, absent from the total.
      expect(t.totalCents, 12750);
    });

    test('a logged cash sale raises the total by exactly its amount', () {
      final before = LedgerMath.totals(specDay).totalCents;
      final after = LedgerMath.totals([...specDay, entry(LedgerKind.cashSale, 5000)]).totalCents;
      expect(after - before, 5000);
    });

    test('entries replaced by a day-close are excluded from every total', () {
      final withClose = [
        entry(LedgerKind.cashSale, 2250, superseded: true),
        entry(LedgerKind.cashSale, 1250, superseded: true),
        entry(LedgerKind.cashSale, 4000),
      ];
      expect(LedgerMath.totals(withClose).cashCents, 4000);
    });

    test('day one with no data is zero, not a broken total', () {
      final t = LedgerMath.totals(const <LedgerEntry>[]);
      expect(t.totalCents, 0);
      expect(t.isEmpty, isTrue);
      expect(Money.format(t.totalCents), r'$0.00');
    });
  });

  group('Fiado balances', () {
    test('te deben = fiados issued minus payments received', () {
      final customers = [customer(1, 'María González'), customer(2, 'Juan Pérez')];
      final entries = [
        entry(LedgerKind.fiadoIssued, 4500, customerId: 1, at: DateTime(2026, 8, 15)),
        entry(LedgerKind.fiadoIssued, 3000, customerId: 2, at: DateTime(2026, 8, 20)),
        entry(LedgerKind.fiadoPayment, 1000, customerId: 2, at: DateTime(2026, 8, 28)),
      ];
      final balances = LedgerMath.balances(customers, entries);
      expect(LedgerMath.outstandingTotal(balances), 6500);
      expect(balances.firstWhere((b) => b.customer.id == 1).balanceCents, 4500);
      expect(balances.firstWhere((b) => b.customer.id == 2).balanceCents, 2000);
    });

    test('recording a payment lowers te deben and counts as income the same day', () {
      final customers = [customer(1, 'Lucía Romero')];
      final base = [entry(LedgerKind.fiadoIssued, 5000, customerId: 1, at: DateTime(2026, 8, 1))];
      final payment = entry(LedgerKind.fiadoPayment, 2000,
          customerId: 1, at: DateTime(2026, 9, 2, 10));

      final before = LedgerMath.outstandingTotal(LedgerMath.balances(customers, base));
      final after =
          LedgerMath.outstandingTotal(LedgerMath.balances(customers, [...base, payment]));

      expect(before - after, 2000);
      // The same $20 shows up as income under "Cobros fiado".
      expect(LedgerMath.totals([payment]).fiadoCollectedCents, 2000);
      expect(LedgerMath.totals([payment]).totalCents, 2000);
    });

    test('payments settle the oldest fiado first, so aging tracks the money owed', () {
      final now = DateTime(2026, 9, 2);
      final customers = [customer(1, 'Ana Vera')];
      final entries = [
        entry(LedgerKind.fiadoIssued, 2000, customerId: 1, at: DateTime(2026, 7, 20)),
        entry(LedgerKind.fiadoIssued, 3000, customerId: 1, at: DateTime(2026, 8, 30)),
        // Clears the old $20 exactly.
        entry(LedgerKind.fiadoPayment, 2000, customerId: 1, at: DateTime(2026, 9, 1)),
      ];
      final b = LedgerMath.balances(customers, entries).single;
      expect(b.balanceCents, 3000);
      // Aged from the 30 Aug fiado still outstanding, not the paid-off July one.
      expect(b.oldestOutstandingAt, DateTime(2026, 8, 30));
      expect(b.isOverdue(now), isFalse);
    });

    test('debt older than 30 days is flagged overdue', () {
      final now = DateTime(2026, 9, 2);
      final customers = [customer(1, 'Lucía Romero')];
      final entries = [
        entry(LedgerKind.fiadoIssued, 2800, customerId: 1, at: DateTime(2026, 7, 29)),
      ];
      final b = LedgerMath.balances(customers, entries).single;
      expect(b.daysOutstanding(now), 35);
      expect(b.isOverdue(now), isTrue);
    });

    test('a settled customer has no outstanding age', () {
      final customers = [customer(1, 'Pedro Luna')];
      final entries = [
        entry(LedgerKind.fiadoIssued, 1500, customerId: 1, at: DateTime(2026, 8, 1)),
        entry(LedgerKind.fiadoPayment, 1500, customerId: 1, at: DateTime(2026, 8, 5)),
      ];
      final b = LedgerMath.balances(customers, entries).single;
      expect(b.balanceCents, 0);
      expect(b.oldestOutstandingAt, isNull);
      expect(b.isOverdue(DateTime(2026, 9, 2)), isFalse);
    });

    test('running balance matches the statement worked through in the spec', () {
      final entries = [
        entry(LedgerKind.fiadoIssued, 4000, customerId: 1, at: DateTime(2026, 8, 15)),
        entry(LedgerKind.fiadoPayment, 2500, customerId: 1, at: DateTime(2026, 8, 20)),
        entry(LedgerKind.fiadoIssued, 2500, customerId: 1, at: DateTime(2026, 8, 25), note: 'gas'),
        entry(LedgerKind.fiadoPayment, 1000, customerId: 1, at: DateTime(2026, 8, 28)),
        entry(LedgerKind.fiadoIssued, 1500,
            customerId: 1, at: DateTime(2026, 9, 1), note: 'arroz y aceite'),
      ];
      final rows = LedgerMath.statement(entries);
      // Newest first, each row showing the balance after that entry.
      expect(rows.map((r) => r.balanceCents).toList(), [4500, 3000, 4000, 1500, 4000]);
      expect(rows.first.entry.note, 'arroz y aceite');
    });
  });

  group('Trend', () {
    test('compares today so far against the same point yesterday', () {
      final now = DateTime(2026, 9, 2, 12);
      final today = [entry(LedgerKind.cashSale, 5600, at: DateTime(2026, 9, 2, 11))];
      final yesterday = [
        entry(LedgerKind.cashSale, 5000, at: DateTime(2026, 9, 1, 11)),
        // After midday: excluded, or every morning would look like a collapse.
        entry(LedgerKind.cashSale, 9000, at: DateTime(2026, 9, 1, 18)),
      ];
      final t = LedgerMath.trend(today: today, yesterday: yesterday, now: now);
      expect(t, closeTo(0.12, 0.0001));
      expect(Money.percent(t!), '12%');
    });

    test('is null when there is no yesterday to compare against', () {
      expect(
        LedgerMath.trend(today: [entry(LedgerKind.cashSale, 100)], yesterday: const [], now: DateTime(2026, 9, 2, 12)),
        isNull,
      );
    });
  });

  group('Weekly chart', () {
    test('returns seven days ending today and marks pre-signup days as placeholders', () {
      final now = DateTime(2026, 9, 2, 16);
      final bars = LedgerMath.weekBars(
        entries: [
          entry(LedgerKind.cashSale, 3000, at: DateTime(2026, 9, 2, 9)),
          entry(LedgerKind.qrSale, 2000, at: DateTime(2026, 8, 31, 9)),
        ],
        now: now,
        firstActivityDay: DateTime(2026, 8, 31),
      );
      expect(bars.length, 7);
      expect(bars.last.day, DateTime(2026, 9, 2));
      expect(bars.last.totalCents, 3000);
      // 27-30 Aug predate any activity: gray placeholders, not $0 days.
      expect(bars.take(4).every((b) => !b.hasData), isTrue);
      expect(bars.skip(4).every((b) => b.hasData), isTrue);
      // 1 Sep is a real day with no sales.
      expect(bars[5].totalCents, 0);
      expect(bars[5].hasData, isTrue);
    });
  });

  group('Double-counting guard', () {
    test('flags a cash sale that looks like a fiado payment just recorded', () {
      final now = DateTime(2026, 9, 2, 12, 0);
      final payments = [
        entry(LedgerKind.fiadoPayment, 1500,
            customerId: 1, createdAt: DateTime(2026, 9, 2, 11, 58)),
      ];
      expect(
        LedgerMath.matchingRecentFiadoPayment(
            recentPayments: payments, amountCents: 1500, now: now),
        isNotNull,
      );
    });

    test('stays quiet for a different amount or an older payment', () {
      final now = DateTime(2026, 9, 2, 12, 0);
      expect(
        LedgerMath.matchingRecentFiadoPayment(
          recentPayments: [
            entry(LedgerKind.fiadoPayment, 8000,
                customerId: 1, createdAt: DateTime(2026, 9, 2, 11, 58)),
          ],
          amountCents: 1500,
          now: now,
        ),
        isNull,
      );
      expect(
        LedgerMath.matchingRecentFiadoPayment(
          recentPayments: [
            entry(LedgerKind.fiadoPayment, 1500,
                customerId: 1, createdAt: DateTime(2026, 9, 2, 11, 30)),
          ],
          amountCents: 1500,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('End-of-day close', () {
    test('subtracts the morning float from the drawer', () {
      expect(LedgerMath.closeoutSales(drawerCents: 12000, floatCents: 2000), 10000);
    });

    test('never books a negative sale from a miscount', () {
      expect(LedgerMath.closeoutSales(drawerCents: 500, floatCents: 2000), 0);
    });
  });

  group('Customer names', () {
    test('suggests an existing match instead of creating a near-duplicate', () {
      final existing = [customer(1, 'María González'), customer(2, 'María García')];
      expect(LedgerMath.similarCustomers('maria gonzalez', existing).first.id, 1);
      expect(LedgerMath.similarCustomers('Maria', existing).length, 2);
      expect(LedgerMath.similarCustomers('Roberto', existing), isEmpty);
    });

    test('avatar colour is stable for a name regardless of case or accent', () {
      final a = LedgerMath.avatarPaletteIndex('María González', 8);
      final b = LedgerMath.avatarPaletteIndex('maria gonzalez', 8);
      expect(a, b);
      expect(a, inInclusiveRange(0, 7));
    });
  });

  group('Money formatting', () {
    test('uses a decimal point and groups thousands', () {
      expect(Money.format(12750), r'$127.50');
      expect(Money.format(0), r'$0.00');
      expect(Money.format(5), r'$0.05');
      expect(Money.format(123456789), r'$1,234,567.89');
      expect(Money.format(-500), r'-$5.00');
      expect(Money.signed(500), r'+$5.00');
      expect(Money.signed(-500), r'-$5.00');
      expect(Money.bare(12750), '127.50');
    });

    test('stays exact at magnitudes where a double would drift', () {
      // Rendering via cents/100 puts money through binary floating point.
      // These are the cases that would start losing pennies if it did.
      expect(Money.format(Money.maxParsableCents), r'$999,999,999.99');
      expect(Money.format(90071992547409911), r'$900,719,925,474,099.11');
      expect(Money.bare(999999999999999999), '9,999,999,999,999,999.99');
    });

    test('parses what a merchant might actually type', () {
      expect(Money.parse('2.50'), 250);
      expect(Money.parse('2,50'), 250);
      expect(Money.parse('2.5'), 250);
      expect(Money.parse(r'$12'), 1200);
      expect(Money.parse('12'), 1200);
      expect(Money.parse('.75'), 75);
      expect(Money.parse('  7.25  '), 725);
      expect(Money.parse('-5'), -500);
    });

    test('reads a three-digit group as thousands, not as decimals', () {
      // The one genuinely ambiguous shape. A thousands separator is always
      // followed by exactly three digits; a decimal point on money is not.
      expect(Money.parse('1,234'), 123400);
      expect(Money.parse('1.234'), 123400);
      expect(Money.parse('1,234.56'), 123456);
      expect(Money.parse('1.234,56'), 123456);
      expect(Money.parse('1,234,567.89'), 123456789);
    });

    test('rounds a long fraction half-up without going through a double', () {
      // 2.675 * 100 is 267.49999999999997 in binary floating point, so the
      // obvious implementation silently loses the cent.
      expect(Money.parse('2.6750'), 268);
      expect(Money.parse('8.1550'), 816);
      expect(Money.parse('0.0050'), 1);
      expect(Money.parse('0.0049'), 0);
      // Rounds up into the next dollar rather than producing 100 cents.
      expect(Money.parse('1.9999'), 200);
    });

    test('rejects anything that is not a number', () {
      expect(Money.parse('abc'), isNull);
      expect(Money.parse(''), isNull);
      expect(Money.parse('   '), isNull);
      expect(Money.parse(r'$'), isNull);
      expect(Money.parse('...'), isNull);
      expect(Money.parse('1e9'), isNull);
      expect(Money.parse('12x'), isNull);
    });

    test('refuses an amount too large to hold, instead of overflowing', () {
      expect(Money.parse('999999999.99'), Money.maxParsableCents);
      expect(Money.parse('1000000000'), isNull);
      expect(Money.parse('99999999999999999999999'), isNull);
    });
  });

  group('Income is an inclusion list', () {
    test('names exactly the four kinds that are money earned', () {
      expect(incomeKinds, {
        LedgerKind.cashSale,
        LedgerKind.qrSale,
        LedgerKind.cardSale,
        LedgerKind.fiadoPayment,
      });
      for (final kind in LedgerKind.values) {
        expect(kind.isIncome, incomeKinds.contains(kind), reason: '$kind');
      }
      expect(LedgerKind.fiadoIssued.isIncome, isFalse);
    });

    test('a newly added kind is not income until it is named', () {
      // A tripwire, not a formality. This fails the moment someone appends a
      // kind, which is exactly when they have to decide whether it is revenue
      // — under the old `!= fiadoIssued` test that decision was made silently
      // and wrongly.
      expect(
        LedgerKind.values.length,
        5,
        reason: 'A LedgerKind was added. Decide explicitly whether it belongs '
            'in incomeKinds, then update this count.',
      );
    });
  });

  group('Voided entries', () {
    test('are excluded from the day total but keep their place on file', () {
      final entries = [
        entry(LedgerKind.cashSale, 2500),
        entry(LedgerKind.cashSale, 1000,
            voidedAt: DateTime(2026, 9, 2, 13), voidedReason: 'Me equivoqué en el monto'),
      ];
      final totals = LedgerMath.totals(entries);
      expect(totals.cashCents, 2500);
      expect(totals.totalCents, 2500);
      // Counted rows only; the voided one is still in the list passed in.
      expect(totals.entryCount, 1);
      expect(entries.length, 2);
    });

    test('a voided fiado stops counting toward what a customer owes', () {
      final customers = [customer(1, 'María González')];
      final live = entry(LedgerKind.fiadoIssued, 4500, customerId: 1, at: DateTime(2026, 8, 15));
      final mistake = entry(LedgerKind.fiadoIssued, 9900,
          customerId: 1,
          at: DateTime(2026, 8, 16),
          voidedAt: DateTime(2026, 8, 16, 12),
          voidedReason: 'Me equivoqué en el monto');

      final balances = LedgerMath.balances(customers, [live, mistake]);
      expect(balances.single.balanceCents, 4500);
      expect(LedgerMath.outstandingTotal(balances), 4500);
    });

    test('a voided payment does not wipe out a debt that is still owed', () {
      final customers = [customer(1, 'Juan Pérez')];
      final entries = [
        entry(LedgerKind.fiadoIssued, 3000, customerId: 1, at: DateTime(2026, 8, 1)),
        entry(LedgerKind.fiadoPayment, 3000,
            customerId: 1,
            at: DateTime(2026, 8, 2),
            voidedAt: DateTime(2026, 8, 2, 10),
            voidedReason: 'No era este cliente'),
      ];
      expect(LedgerMath.balances(customers, entries).single.balanceCents, 3000);
    });

    test('stay in the statement without moving the running balance', () {
      final entries = [
        entry(LedgerKind.fiadoIssued, 4000, customerId: 1, at: DateTime(2026, 8, 15)),
        entry(LedgerKind.fiadoIssued, 9900,
            customerId: 1,
            at: DateTime(2026, 8, 16),
            voidedAt: DateTime(2026, 8, 16, 12),
            voidedReason: 'Me equivoqué en el monto'),
        entry(LedgerKind.fiadoPayment, 1000, customerId: 1, at: DateTime(2026, 8, 20)),
      ];
      final rows = LedgerMath.statement(entries);

      // Newest first. The voided row is listed — that is the whole point — and
      // the balance beside it is the balance as it actually stood.
      expect(rows.length, 3);
      expect(rows.map((r) => r.balanceCents).toList(), [3000, 4000, 4000]);
      expect(rows[1].entry.isVoided, isTrue);
      expect(rows[1].entry.voidedReason, 'Me equivoqué en el monto');
    });

    test('do not count toward the trend or the weekly chart', () {
      final now = DateTime(2026, 9, 2, 12);
      final today = [
        entry(LedgerKind.cashSale, 5000, at: DateTime(2026, 9, 2, 11)),
        entry(LedgerKind.cashSale, 9900,
            at: DateTime(2026, 9, 2, 11, 30), voidedAt: now, voidedReason: 'Lo registré dos veces'),
      ];
      final yesterday = [entry(LedgerKind.cashSale, 5000, at: DateTime(2026, 9, 1, 11))];

      expect(LedgerMath.trend(today: today, yesterday: yesterday, now: now), 0.0);

      final bars = LedgerMath.weekBars(
        entries: today,
        now: now,
        firstActivityDay: DateTime(2026, 9, 1),
      );
      expect(bars.last.totalCents, 5000);
    });
  });
}
