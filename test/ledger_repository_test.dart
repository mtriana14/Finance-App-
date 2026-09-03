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
    test('an entry can be deleted within 24 hours', () async {
      final id = await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);
      expect(await ledger.deleteEntry(id), isTrue);
      expect(await ledger.watchDay(DateTime.now()).first, isEmpty);
    });

    test('the delete window closes after 24 hours', () async {
      final id = await ledger.addSale(kind: LedgerKind.cashSale, amountCents: 500);
      final tomorrow = DateTime.now().add(const Duration(hours: 25));
      expect(await ledger.deleteEntry(id, now: tomorrow), isFalse);
      expect((await ledger.watchDay(DateTime.now()).first).length, 1);
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
}
