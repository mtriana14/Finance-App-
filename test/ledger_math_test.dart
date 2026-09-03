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
      expect(Money.format(123456789), r'$1,234,567.89');
      expect(Money.format(-500), r'-$5.00');
    });

    test('parses what a merchant might actually type', () {
      expect(Money.parse('2.50'), 250);
      expect(Money.parse('2,50'), 250);
      expect(Money.parse(r'$12'), 1200);
      expect(Money.parse('1,234.56'), 123456);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse(''), isNull);
    });
  });
}
