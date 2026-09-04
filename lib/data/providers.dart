import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/customer.dart';
import '../domain/models/daily_totals.dart';
import '../domain/models/ledger_entry.dart';
import '../domain/models/ledger_kind.dart';
import '../domain/services/ledger_math.dart';
import 'db/database.dart';
import 'repositories/customer_repository.dart';
import 'repositories/ledger_repository.dart';
import 'repositories/settings_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final ledgerRepositoryProvider =
    Provider<LedgerRepository>((ref) => LedgerRepository(ref.watch(databaseProvider)));

final customerRepositoryProvider =
    Provider<CustomerRepository>((ref) => CustomerRepository(ref.watch(databaseProvider)));

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(databaseProvider)));

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Today, re-emitted when the clock rolls past midnight so a merchant who
/// leaves the app open overnight doesn't wake up to yesterday's dashboard.
///
/// The rollover is a cancellable [Timer] rather than an awaited delay so it is
/// torn down with the provider instead of outliving it.
final todayProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void emit() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    controller.add(day);
    timer = Timer(
      day.add(const Duration(days: 1)).difference(now) + const Duration(seconds: 1),
      emit,
    );
  }

  emit();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

// ---------------------------------------------------------------------------
// Ledger streams
// ---------------------------------------------------------------------------

final todayEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final day = ref.watch(todayProvider).value;
  if (day == null) return const Stream.empty();
  return ref.watch(ledgerRepositoryProvider).watchDay(day);
});

final yesterdayEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final day = ref.watch(todayProvider).value;
  if (day == null) return const Stream.empty();
  return ref.watch(ledgerRepositoryProvider).watchDay(day.subtract(const Duration(days: 1)));
});

/// The seven days behind the mini chart.
final weekEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final day = ref.watch(todayProvider).value;
  if (day == null) return const Stream.empty();
  return ref.watch(ledgerRepositoryProvider).watchRange(day.subtract(const Duration(days: 6)), day);
});

/// What Historial is currently showing. Used as a provider key, so it needs
/// value equality.
@immutable
class HistorialQuery {
  const HistorialQuery({this.kinds, this.from, this.to, this.dayLimit = 12});

  /// Null or empty means every channel.
  final Set<LedgerKind>? kinds;
  final DateTime? from;
  final DateTime? to;

  /// How many days deep the list is scrolled. Grows on "Ver más días".
  final int dayLimit;

  @override
  bool operator ==(Object other) =>
      other is HistorialQuery &&
      setEquals(kinds, other.kinds) &&
      from == other.from &&
      to == other.to &&
      dayLimit == other.dayLimit;

  @override
  int get hashCode => Object.hash(
        kinds == null ? null : Object.hashAllUnordered(kinds!),
        from,
        to,
        dayLimit,
      );
}

/// Historial reads a bounded window rather than the whole ledger: a merchant
/// with three years of daily sales has tens of thousands of rows, and none of
/// the ones off screen need to be in memory.
///
/// autoDispose so changing a filter releases the previous query's subscription.
final historialProvider =
    StreamProvider.autoDispose.family<HistorialPage, HistorialQuery>((ref, query) {
  return ref.watch(ledgerRepositoryProvider).watchHistorial(
        kinds: query.kinds,
        from: query.from,
        to: query.to,
        dayLimit: query.dayLimit,
      );
});


final fiadoEntriesProvider =
    StreamProvider<List<LedgerEntry>>((ref) => ref.watch(ledgerRepositoryProvider).watchAllFiado());

final customerEntriesProvider =
    StreamProvider.family<List<LedgerEntry>, int>((ref, customerId) {
  return ref.watch(ledgerRepositoryProvider).watchForCustomer(customerId);
});

final firstActivityDayProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchFirstActivityDay(),
);

// ---------------------------------------------------------------------------
// Derived state
//
// Every screen that shows a total reads one of these, and each is computed by
// LedgerMath from the same rows. That is what keeps the customer's balance,
// the Libreta summary bar and the dashboard's "Te deben" in agreement — they
// are the same number, not three numbers that happen to match.
// ---------------------------------------------------------------------------

final todayTotalsProvider = Provider<DailyTotals>((ref) {
  final entries = ref.watch(todayEntriesProvider).value ?? const [];
  return LedgerMath.totals(entries);
});

final trendProvider = Provider<double?>((ref) {
  final today = ref.watch(todayEntriesProvider).value;
  final yesterday = ref.watch(yesterdayEntriesProvider).value;
  if (today == null || yesterday == null) return null;
  return LedgerMath.trend(today: today, yesterday: yesterday, now: DateTime.now());
});

final weekBarsProvider = Provider<List<DayBar>>((ref) {
  final entries = ref.watch(weekEntriesProvider).value ?? const [];
  final day = ref.watch(todayProvider).value ?? DateTime.now();
  final firstActivity = ref.watch(firstActivityDayProvider).value;
  return LedgerMath.weekBars(entries: entries, now: day, firstActivityDay: firstActivity);
});

/// Cash logged one sale at a time today, excluding anything a day-close has
/// already replaced. Reactive, so the "esto REEMPLAZA" warning tracks what the
/// merchant has actually entered.
final individualCashTodayProvider = Provider<int>((ref) {
  final entries = ref.watch(todayEntriesProvider).value ?? const [];
  return entries
      .where((e) =>
          e.kind == LedgerKind.cashSale && !e.isCloseout && !e.supersededByCloseout)
      .fold(0, (sum, e) => sum + e.amountCents);
});

final customersProvider =
    StreamProvider<List<Customer>>((ref) => ref.watch(customerRepositoryProvider).watchAll());

/// Every customer with their outstanding balance and aging, sorted for the
/// Libreta list: biggest debt first by default, most recent on request.
final balancesProvider = Provider<List<CustomerBalance>>((ref) {
  final customers = ref.watch(customersProvider).value ?? const [];
  final fiados = ref.watch(fiadoEntriesProvider).value ?? const [];
  final sortByRecent = ref.watch(settingsProvider).value?.sortByRecent ?? false;

  final all = LedgerMath.balances(customers, fiados);
  final withDebt = all.where((b) => b.hasDebt).toList();

  withDebt.sort((a, b) {
    if (sortByRecent) {
      final at = a.lastFiadoAt, bt = b.lastFiadoAt;
      if (at == null && bt == null) return a.customer.name.compareTo(b.customer.name);
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    }
    final byAmount = b.balanceCents.compareTo(a.balanceCents);
    return byAmount != 0 ? byAmount : a.customer.name.compareTo(b.customer.name);
  });
  return withDebt;
});

/// "Te deben" — one number, read by both the Libreta summary bar and the
/// dashboard card.
final outstandingTotalProvider =
    Provider<int>((ref) => LedgerMath.outstandingTotal(ref.watch(balancesProvider)));

final customerBalanceProvider = Provider.family<CustomerBalance?, int>((ref, id) {
  final customers = ref.watch(customersProvider).value ?? const [];
  final match = customers.where((c) => c.id == id).toList();
  if (match.isEmpty) return null;
  final fiados = ref.watch(fiadoEntriesProvider).value ?? const [];
  return LedgerMath.balances(match, fiados).single;
});
