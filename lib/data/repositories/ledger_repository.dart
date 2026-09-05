import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/format/dates.dart';
import '../../domain/models/ledger_entry.dart';
import '../../domain/models/ledger_kind.dart';
import '../../domain/services/ledger_math.dart';
import '../db/database.dart';

/// Reads and writes the ledger.
///
/// Queries here return *everything*, including entries a day-close has
/// replaced, and leave the "does this count?" decision to [LedgerMath]. That is
/// what stops two screens from disagreeing: Historial needs to show a replaced
/// entry grayed out, the dashboard needs to ignore it, and both are looking at
/// the same rows.
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  Stream<List<LedgerEntry>> _watchJoined(Expression<bool> Function($LedgerEntriesTable t) where) {
    final query = _db.select(_db.ledgerEntries).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.ledgerEntries.customerId)),
    ])
      ..where(where(_db.ledgerEntries))
      ..orderBy([
        OrderingTerm.desc(_db.ledgerEntries.occurredAt),
        OrderingTerm.desc(_db.ledgerEntries.id),
      ]);

    return query.watch().map(
          (rows) => [
            for (final row in rows)
              row.readTable(_db.ledgerEntries).toDomain(
                    customerName: row.readTableOrNull(_db.customers)?.name,
                  ),
          ],
        );
  }

  Stream<List<LedgerEntry>> watchDay(DateTime day) {
    final key = Dates.businessDay(day);
    return _watchJoined((t) => t.businessDay.equals(key));
  }

  /// Inclusive on both ends, by business day.
  Stream<List<LedgerEntry>> watchRange(DateTime from, DateTime to) {
    final a = Dates.businessDay(from);
    final b = Dates.businessDay(to);
    return _watchJoined((t) => t.businessDay.isBetweenValues(a, b));
  }

  Stream<List<LedgerEntry>> watchAllFiado() => _watchJoined(
        (t) => t.kind.isInValues([LedgerKind.fiadoIssued, LedgerKind.fiadoPayment]),
      );

  Stream<List<LedgerEntry>> watchForCustomer(int customerId) =>
      _watchJoined((t) => t.customerId.equals(customerId));

  /// The day the merchant first logged anything, so the 7-day chart can tell a
  /// genuine $0 day from a day before they started.
  Stream<DateTime?> watchFirstActivityDay() {
    final min = _db.ledgerEntries.businessDay.min();
    final query = _db.selectOnly(_db.ledgerEntries)..addColumns([min]);
    return query.watchSingleOrNull().map((row) {
      final value = row?.read(min);
      return value == null ? null : Dates.fromBusinessDay(value);
    });
  }

  /// Cash logged one sale at a time today, ignoring anything a previous close
  /// already replaced. Drives the "esto REEMPLAZA" warning.
  Future<int> individualCashFor(DateTime day) async {
    final key = Dates.businessDay(day);
    final sum = _db.ledgerEntries.amountCents.sum();
    final query = _db.selectOnly(_db.ledgerEntries)
      ..addColumns([sum])
      ..where(_db.ledgerEntries.businessDay.equals(key) &
          _db.ledgerEntries.kind.equalsValue(LedgerKind.cashSale) &
          _db.ledgerEntries.isCloseout.equals(false) &
          _db.ledgerEntries.supersededByCloseout.equals(false));
    final row = await query.getSingleOrNull();
    return row?.read(sum) ?? 0;
  }

  Future<bool> hasCloseoutFor(DateTime day) async {
    final key = Dates.businessDay(day);
    final query = _db.select(_db.ledgerEntries)
      ..where((t) =>
          t.businessDay.equals(key) &
          t.isCloseout.equals(true) &
          t.supersededByCloseout.equals(false))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Fiado payments recorded in the last few minutes — the input to the
  /// double-counting guard.
  Future<List<LedgerEntry>> recentFiadoPayments({
    required DateTime now,
    Duration window = const Duration(minutes: 5),
  }) async {
    final since = now.subtract(window);
    final query = _db.select(_db.ledgerEntries)
      ..where((t) => t.kind.equalsValue(LedgerKind.fiadoPayment) & t.createdAt.isBiggerThanValue(since))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return [for (final row in await query.get()) row.toDomain()];
  }

  // ---------------------------------------------------------------------------
  // Historial paging
  // ---------------------------------------------------------------------------

  /// A page of Historial: complete days, newest first.
  ///
  /// Paging by *day* rather than by row is what keeps the daily totals honest.
  /// A row-based page would cut some day in half at the boundary and print a
  /// section total for a day it had only partly loaded.
  /// The subscription is managed explicitly rather than written as an `async*`
  /// generator: a generator suspended in `await for` over the never-ending
  /// change feed cannot be cancelled, so every filter change would strand a
  /// listener on the database.
  Stream<HistorialPage> watchHistorial({
    Set<LedgerKind>? kinds,
    DateTime? from,
    DateTime? to,
    int dayLimit = 12,
  }) {
    final controller = StreamController<HistorialPage>();
    StreamSubscription<void>? changes;
    var cancelled = false;

    Future<void> emit() async {
      if (cancelled) return;
      final page =
          await _loadHistorial(kinds: kinds, from: from, to: to, dayLimit: dayLimit);
      // The read is asynchronous, so re-check: the listener may have gone away
      // while SQLite was working.
      if (!cancelled && !controller.isClosed) controller.add(page);
    }

    controller.onListen = () {
      // Re-read when either table the page draws from changes — the ledger for
      // the rows, customers because a fiado row carries their name.
      changes = _db
          .tableUpdates(TableUpdateQuery.allOf([
            TableUpdateQuery.onTable(_db.ledgerEntries),
            TableUpdateQuery.onTable(_db.customers),
          ]))
          .listen((_) => emit());
      emit();
    };
    controller.onCancel = () async {
      cancelled = true;
      await changes?.cancel();
    };

    return controller.stream;
  }

  Expression<bool>? _historialFilter({
    required Set<LedgerKind>? kinds,
    required DateTime? from,
    required DateTime? to,
  }) {
    final terms = <Expression<bool>>[
      if (kinds != null && kinds.isNotEmpty)
        _db.ledgerEntries.kind.isInValues(kinds.toList()),
      if (from != null) _db.ledgerEntries.businessDay.isBiggerOrEqualValue(Dates.businessDay(from)),
      if (to != null) _db.ledgerEntries.businessDay.isSmallerOrEqualValue(Dates.businessDay(to)),
    ];
    if (terms.isEmpty) return null;
    return terms.reduce((a, b) => a & b);
  }

  Future<HistorialPage> _loadHistorial({
    required Set<LedgerKind>? kinds,
    required DateTime? from,
    required DateTime? to,
    required int dayLimit,
  }) async {
    final filter = _historialFilter(kinds: kinds, from: from, to: to);
    final dayColumn = _db.ledgerEntries.businessDay;

    // One extra day is fetched purely to answer "is there more?".
    final dayQuery = _db.selectOnly(_db.ledgerEntries, distinct: true)
      ..addColumns([dayColumn])
      ..orderBy([OrderingTerm.desc(dayColumn)])
      ..limit(dayLimit + 1);
    if (filter != null) dayQuery.where(filter);

    final dayRows = await dayQuery.get();
    final allDays = [for (final row in dayRows) row.read(dayColumn)!];
    final days = allDays.take(dayLimit).toList();
    if (days.isEmpty) return const HistorialPage(entries: [], hasMoreDays: false);

    final entryQuery = _db.select(_db.ledgerEntries).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.ledgerEntries.customerId)),
    ])
      ..where(filter == null
          ? dayColumn.isIn(days)
          : dayColumn.isIn(days) & filter)
      ..orderBy([
        OrderingTerm.desc(_db.ledgerEntries.occurredAt),
        OrderingTerm.desc(_db.ledgerEntries.id),
      ]);

    final rows = await entryQuery.get();
    return HistorialPage(
      entries: [
        for (final row in rows)
          row.readTable(_db.ledgerEntries).toDomain(
                customerName: row.readTableOrNull(_db.customers)?.name,
              ),
      ],
      hasMoreDays: allDays.length > dayLimit,
    );
  }

  /// Full dump for CSV export, oldest first so the file reads like a ledger.
  Future<List<LedgerEntry>> exportAll() async {
    final query = _db.select(_db.ledgerEntries).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.ledgerEntries.customerId)),
    ])
      ..orderBy([OrderingTerm.asc(_db.ledgerEntries.occurredAt)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        row.readTable(_db.ledgerEntries).toDomain(
              customerName: row.readTableOrNull(_db.customers)?.name,
            ),
    ];
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  Future<int> addSale({
    required LedgerKind kind,
    required int amountCents,
    String? note,
    int? customerId,
    DateTime? occurredAt,
    EntrySource source = EntrySource.manual,
  }) {
    final when = occurredAt ?? DateTime.now();
    return _db.into(_db.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            kind: kind,
            amountCents: amountCents,
            occurredAt: when,
            businessDay: Dates.businessDay(when),
            note: Value(_trimNote(note)),
            customerId: Value(customerId),
            source: Value(source),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<int> addFiado({required int customerId, required int amountCents, String? note}) =>
      addSale(
        kind: LedgerKind.fiadoIssued,
        amountCents: amountCents,
        note: note,
        customerId: customerId,
      );

  Future<int> addFiadoPayment({required int customerId, required int amountCents, String? note}) =>
      addSale(
        kind: LedgerKind.fiadoPayment,
        amountCents: amountCents,
        note: note,
        customerId: customerId,
      );

  /// End-of-day reconciliation.
  ///
  /// This *replaces* the day's cash rather than adding to it: every cash entry
  /// still standing for that day is marked superseded (including an earlier
  /// close, so re-running it doesn't stack), and one close entry is written in
  /// their place. Superseded rows are never deleted — Historial still shows
  /// them, grayed, so the merchant can see what the close absorbed.
  Future<void> saveCloseout({
    required DateTime day,
    required int drawerCents,
    required int floatCents,
  }) async {
    final key = Dates.businessDay(day);
    final sales = LedgerMath.closeoutSales(drawerCents: drawerCents, floatCents: floatCents);
    final now = DateTime.now();
    // A close is stamped at the moment it is saved, unless it is being written
    // for a past day, where it lands at the end of that day.
    final occurredAt = Dates.businessDay(now) == key
        ? now
        : DateTime(day.year, day.month, day.day, 23, 59);

    await _db.transaction(() async {
      await (_db.update(_db.ledgerEntries)
            ..where((t) =>
                t.businessDay.equals(key) &
                t.kind.equalsValue(LedgerKind.cashSale) &
                t.supersededByCloseout.equals(false)))
          .write(const LedgerEntriesCompanion(supersededByCloseout: Value(true)));

      await _db.into(_db.ledgerEntries).insert(
            LedgerEntriesCompanion.insert(
              kind: LedgerKind.cashSale,
              amountCents: sales,
              occurredAt: occurredAt,
              businessDay: key,
              note: const Value('Cierre del día'),
              isCloseout: const Value(true),
              createdAt: now,
            ),
          );
    });
  }

  /// Mistake correction, allowed only within 24 hours of logging.
  ///
  /// This voids the row; it never deletes it. A merchant uses this ledger to
  /// settle an argument about who owes what, and an entry that can disappear
  /// without a trace is worth less than the paper notebook it replaced. The
  /// voided row keeps its place in the statement, struck through, alongside
  /// the reason the merchant gave.
  ///
  /// Returns false if the entry is gone, already voided, or past the window.
  Future<bool> voidEntry(int id, {required String reason, DateTime? now}) async {
    final at = now ?? DateTime.now();
    final row = await (_db.select(_db.ledgerEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return false;

    final entry = row.toDomain();
    if (entry.isVoided || !entry.deletableAt(at)) return false;

    await (_db.update(_db.ledgerEntries)..where((t) => t.id.equals(id))).write(
      LedgerEntriesCompanion(
        voidedAt: Value(at),
        voidedReason: Value(_trimNote(reason)),
      ),
    );
    return true;
  }

  /// Erases the ledger outright. This is the merchant deleting their own data
  /// from Perfil — not a correction — so it is the one place a real DELETE is
  /// the right thing.
  Future<void> deleteAll() => _db.delete(_db.ledgerEntries).go();

  static String? _trimNote(String? note) {
    final t = note?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length <= 80 ? t : t.substring(0, 80);
  }
}

/// A day-bounded slice of the ledger, plus whether older days remain.
class HistorialPage {
  const HistorialPage({required this.entries, required this.hasMoreDays});

  final List<LedgerEntry> entries;
  final bool hasMoreDays;

  static const empty = HistorialPage(entries: [], hasMoreDays: false);
}
