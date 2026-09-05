import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreta/data/db/database.dart';
import 'package:libreta/data/repositories/customer_repository.dart';
import 'package:libreta/data/repositories/ledger_repository.dart';
import 'package:libreta/data/repositories/settings_repository.dart';
import 'package:libreta/domain/models/ledger_kind.dart';
import 'package:libreta/domain/services/ledger_math.dart';

/// Exercises the rules that only exist once real rows are on disk — above all
/// the end-of-day close, which is the one write in the app that mutates
/// entries the merchant already saved.
void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late CustomerRepository customers;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db);
    customers = CustomerRepository(db);
    settings = SettingsRepository(db);
  });

  tearDown(() => db.close());

  group('End-of-day reconciliation', () {
    test('replaces the day\'s individual cash entries instead of adding to them', () async {
      final today = DateTime.now();
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 2250, occurredAt: today);
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 1250, occurredAt: today);

      expect(await ledger.individualCashFor(today), 3500);

      await ledger.saveCloseout(day: today, drawerCents: 12000, floatCents: 2000);

      final entries = await ledger.watchDay(today).first;
      final totals = LedgerMath.totals(entries);

      // $100 counted, not $100 + the $35 already logged.
      expect(totals.cashCents, 10000);
      expect(totals.totalCents, 10000);

      // The replaced rows survive for the audit trail.
      final superseded = entries.where((e) => e.supersededByCloseout).toList();
      expect(superseded.length, 2);
      expect(superseded.map((e) => e.amountCents).toList()..sort(), [1250, 2250]);
    });

    test('re-running the close replaces the previous close rather than stacking', () async {
      final today = DateTime.now();
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 1000, occurredAt: today);
      await ledger.saveCloseout(day: today, drawerCents: 8000, floatCents: 0);
      await ledger.saveCloseout(day: today, drawerCents: 9500, floatCents: 0);

      final totals = LedgerMath.totals(await ledger.watchDay(today).first);
      expect(totals.cashCents, 9500);

      expect(await ledger.hasCloseoutFor(today), isTrue);
    });

    test('leaves other channels and other days untouched', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      await ledger.addSale(kind: LedgerKind.qrSale, amountCents: 4500, occurredAt: today);
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 3000, occurredAt: yesterday);

      await ledger.saveCloseout(day: today, drawerCents: 5000, floatCents: 0);

      final todayTotals = LedgerMath.totals(await ledger.watchDay(today).first);
      expect(todayTotals.qrCents, 4500);
      expect(todayTotals.cashCents, 5000);
      expect(todayTotals.totalCents, 9500);

      final yesterdayTotals = LedgerMath.totals(await ledger.watchDay(yesterday).first);
      expect(yesterdayTotals.cashCents, 3000);
    });

    test('uses the float from settings', () async {
      await settings.setCashFloat(2000);
      final stored = await settings.read();
      expect(stored.cashFloatCents, 2000);

      final today = DateTime.now();
      await ledger.saveCloseout(
          day: today, drawerCents: 12000, floatCents: stored.cashFloatCents);
      expect(LedgerMath.totals(await ledger.watchDay(today).first).cashCents, 10000);
    });
  });

  group('Fiado round trip', () {
    test('a payment updates the customer balance and the day total together', () async {
      final maria = await customers.create(name: 'María González');
      await ledger.addFiado(customerId: maria.id, amountCents: 4500, note: 'víveres');

      var balances = LedgerMath.balances([maria], await ledger.watchAllFiado().first);
      expect(LedgerMath.outstandingTotal(balances), 4500);

      await ledger.addFiadoPayment(customerId: maria.id, amountCents: 1500);

      balances = LedgerMath.balances([maria], await ledger.watchAllFiado().first);
      expect(LedgerMath.outstandingTotal(balances), 3000);

      final today = LedgerMath.totals(await ledger.watchDay(DateTime.now()).first);
      expect(today.fiadoCollectedCents, 1500);
      // The fiado issued is in the day's entries but not in the total.
      expect(today.fiadoIssuedCents, 4500);
      expect(today.totalCents, 1500);
    });

    test('deleting a customer removes their ledger entries', () async {
      final c = await customers.create(name: 'Temporal');
      await ledger.addFiado(customerId: c.id, amountCents: 1000);
      expect((await ledger.watchAllFiado().first).length, 1);

      await customers.delete(c.id);
      expect(await ledger.watchAllFiado().first, isEmpty);
    });
  });

  group('Mistake correction', () {
    test('voiding keeps the row and stops it counting', () async {
      final id = await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);
      expect(
        await ledger.voidEntry(id, reason: 'Me equivoqué en el monto'),
        isTrue,
      );

      final entries = await ledger.watchDay(DateTime.now()).first;
      // The row survives — this is the difference between a void and a delete.
      expect(entries.length, 1);
      final voided = entries.single;
      expect(voided.isVoided, isTrue);
      expect(voided.voidedReason, 'Me equivoqué en el monto');
      expect(voided.voidedAt, isNotNull);
      expect(LedgerMath.totals(entries).totalCents, 0);
    });

    test('a fiado voided by mistake leaves the customer owing nothing extra',
        () async {
      final ana = await customers.create(name: 'Ana Vera');
      await ledger.addFiado(customerId: ana.id, amountCents: 2000);
      final wrong = await ledger.addFiado(customerId: ana.id, amountCents: 9900);

      await ledger.voidEntry(wrong, reason: 'Me equivoqué en el monto');

      final balances =
          LedgerMath.balances([ana], await ledger.watchAllFiado().first);
      expect(LedgerMath.outstandingTotal(balances), 2000);
      // Both rows are still on file for the customer to see.
      expect((await ledger.watchForCustomer(ana.id).first).length, 2);
    });

    test('the correction window closes after 24 hours', () async {
      final id = await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);
      final tomorrow = DateTime.now().add(const Duration(hours: 25));
      expect(await ledger.voidEntry(id, reason: 'tarde', now: tomorrow), isFalse);

      final entry = (await ledger.watchDay(DateTime.now()).first).single;
      expect(entry.isVoided, isFalse);
      expect(LedgerMath.totals([entry]).totalCents, 500);
    });

    test('an entry cannot be voided twice', () async {
      final id = await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);
      expect(await ledger.voidEntry(id, reason: 'primera'), isTrue);
      expect(await ledger.voidEntry(id, reason: 'segunda'), isFalse);

      // The first reason stands; a second attempt does not overwrite history.
      final entry = (await ledger.watchDay(DateTime.now()).first).single;
      expect(entry.voidedReason, 'primera');
    });

    test('voiding a missing entry reports failure rather than throwing', () async {
      expect(await ledger.voidEntry(9999, reason: 'no existe'), isFalse);
    });
  });

  group('Customers', () {
    test('search ignores accents and case', () async {
      await customers.create(name: 'María González');
      await customers.create(name: 'Juan Pérez');

      expect((await customers.search('maria').first).single.name, 'María González');
      expect((await customers.search('PEREZ').first).single.name, 'Juan Pérez');
      expect(await customers.search('zzz').first, isEmpty);
    });

    test('notes are capped at the shared 80-character limit', () async {
      final id = await ledger.addSale(
        kind: LedgerKind.cashSale,
        amountCents: 500,
        note: 'x' * 200,
      );
      final row = (await ledger.watchDay(DateTime.now()).first).firstWhere((e) => e.id == id);
      expect(row.note!.length, 80);
    });
  });

  group('First activity day', () {
    test('is the earliest logged day, and null before anything is logged', () async {
      expect(await ledger.watchFirstActivityDay().first, isNull);

      final old = DateTime.now().subtract(const Duration(days: 3));
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 100, occurredAt: old);
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 100);

      final first = await ledger.watchFirstActivityDay().first;
      expect(first, DateTime(old.year, old.month, old.day));
    });
  });

  group('Historial paging', () {
    /// Seeds [days] consecutive days ending today, one cash sale each.
    Future<void> seedDays(int days) async {
      final today = DateTime.now();
      for (var i = 0; i < days; i++) {
        await ledger.addSale(
          kind: LedgerKind.cashSale,
          amountCents: 100 * (i + 1),
          occurredAt: today.subtract(Duration(days: i)),
        );
      }
    }

    test('returns only the requested number of days and reports more', () async {
      await seedDays(20);

      final page = await ledger.watchHistorial(dayLimit: 12).first;
      final days = LedgerMath.groupByDay(page.entries);

      expect(days.length, 12);
      expect(page.hasMoreDays, isTrue);
      // Newest first.
      expect(days.first.day.day, DateTime.now().day);
    });

    test('reports no more days once the whole ledger fits', () async {
      await seedDays(5);
      final page = await ledger.watchHistorial(dayLimit: 12).first;
      expect(LedgerMath.groupByDay(page.entries).length, 5);
      expect(page.hasMoreDays, isFalse);
    });

    test('a day at the page boundary comes back whole, so its total is right',
        () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      // Yesterday has three sales; it is the last day of a one-day page.
      for (final cents in [1000, 2000, 3000]) {
        await ledger.addSale(
          kind: LedgerKind.cashSale,
          amountCents: cents,
          occurredAt: yesterday,
        );
      }
      await ledger.addSale(
        kind: LedgerKind.cashSale,
        amountCents: 500,
        occurredAt: today,
      );

      // Two days requested: yesterday must arrive complete, not cut off at
      // some row limit, or its section total would understate the day.
      final page = await ledger.watchHistorial(dayLimit: 2).first;
      final days = LedgerMath.groupByDay(page.entries);
      expect(days.length, 2);
      expect(days.last.entries.length, 3);
      expect(days.last.totals.totalCents, 6000);
      expect(days.first.totals.totalCents, 500);
    });

    test('filtering by channel narrows the days as well as the rows', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      await ledger.addSale(
          kind: LedgerKind.cashSale, amountCents: 1000, occurredAt: yesterday);
      await ledger.addSale(kind: LedgerKind.qrSale, amountCents: 2500, occurredAt: today);

      final qrOnly =
          await ledger.watchHistorial(kinds: {LedgerKind.qrSale}).first;
      final days = LedgerMath.groupByDay(qrOnly.entries);

      // Yesterday had no QR sale, so it is not a day in this view at all.
      expect(days.length, 1);
      expect(days.single.totals.totalCents, 2500);
    });

    test('the fiado filter covers credit given and credit collected', () async {
      final c = await customers.create(name: 'Ana Vera');
      await ledger.addFiado(customerId: c.id, amountCents: 4000);
      await ledger.addFiadoPayment(customerId: c.id, amountCents: 1500);
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 900);

      final page = await ledger.watchHistorial(
        kinds: {LedgerKind.fiadoIssued, LedgerKind.fiadoPayment},
      ).first;

      expect(page.entries.length, 2);
      final totals = LedgerMath.totals(page.entries);
      // Only the payment is income; the fiado issued is listed, not counted.
      expect(totals.totalCents, 1500);
      expect(totals.fiadoIssuedCents, 4000);
    });

    test('a date range limits the days returned', () async {
      await seedDays(10);
      final today = DateTime.now();
      final page = await ledger
          .watchHistorial(
            from: today.subtract(const Duration(days: 3)),
            to: today.subtract(const Duration(days: 1)),
          )
          .first;

      expect(LedgerMath.groupByDay(page.entries).length, 3);
      expect(page.hasMoreDays, isFalse);
    });

    test('re-emits when a sale is logged', () async {
      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);

      final totals = <int>[];
      final sub = ledger
          .watchHistorial()
          .listen((p) => totals.add(LedgerMath.totals(p.entries).totalCents));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 250);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(totals.first, 500);
      expect(totals.last, 750);
    });
  });
}
