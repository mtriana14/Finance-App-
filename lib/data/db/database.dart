import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/customer.dart';
import '../../domain/models/ledger_entry.dart';
import '../../domain/models/ledger_kind.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Customers, LedgerEntries, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'libreta'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Historial and the Libreta list are both ordered scans; these two
          // indexes are what keep them fast once a merchant has a year of data.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_ledger_day ON ledger_entries (business_day DESC, occurred_at DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_ledger_customer ON ledger_entries (customer_id, occurred_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_customer_search ON customers (search_key)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Voiding replaces the hard delete. Both columns are nullable, so
            // every existing row is simply "not voided" and no data moves.
            await m.addColumn(ledgerEntries, ledgerEntries.voidedAt);
            await m.addColumn(ledgerEntries, ledgerEntries.voidedReason);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

// ---------------------------------------------------------------------------
// Row -> domain mapping. Screens never see a drift type.
// ---------------------------------------------------------------------------

extension CustomerRowX on CustomerRow {
  Customer toDomain() =>
      Customer(id: id, name: name, phone: phone, createdAt: createdAt);
}

extension LedgerRowX on LedgerRow {
  LedgerEntry toDomain({String? customerName}) => LedgerEntry(
        id: id,
        kind: kind,
        amountCents: amountCents,
        occurredAt: occurredAt,
        note: note,
        customerId: customerId,
        customerName: customerName,
        source: source,
        isCloseout: isCloseout,
        supersededByCloseout: supersededByCloseout,
        voidedAt: voidedAt,
        voidedReason: voidedReason,
        createdAt: createdAt,
      );
}
