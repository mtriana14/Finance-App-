import 'package:drift/drift.dart';

import '../../domain/models/ledger_kind.dart';

@DataClassName('CustomerRow')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The only required field. Phone is optional and nothing else is collected.
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get phone => text().nullable().withLength(max: 24)();

  /// Accent-stripped lowercase name, kept as a column so search stays an
  /// indexed query rather than a scan through Dart.
  TextColumn get searchKey => text()();

  DateTimeColumn get createdAt => dateTime()();
}

/// One table for every movement of money.
///
/// A single ledger is what makes Historial a single query, keeps the dashboard
/// total and its breakdown provably consistent, and leaves exactly one place
/// where the "is this income?" question is answered.
@DataClassName('LedgerRow')
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kind => intEnum<LedgerKind>()();

  /// Always positive, always integer cents. Direction comes from [kind].
  IntColumn get amountCents => integer()();

  DateTimeColumn get occurredAt => dateTime()();

  /// `yyyymmdd`, denormalised so day grouping and the end-of-day close never
  /// need timezone arithmetic in SQL.
  IntColumn get businessDay => integer()();

  TextColumn get note => text().nullable().withLength(max: 80)();

  /// Written as a raw constraint rather than `references()`: the generator in
  /// this toolchain silently drops the typed form, leaving no foreign key at
  /// all, and deleting a customer has to take their fiado history with it.
  IntColumn get customerId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES customers(id) ON DELETE CASCADE')();

  IntColumn get source => intEnum<EntrySource>().withDefault(const Constant(0))();

  /// Marks the single entry written by an end-of-day reconciliation.
  BoolColumn get isCloseout => boolean().withDefault(const Constant(false))();

  /// Set when a day-close replaced this entry. The row is kept for the audit
  /// trail and shown grayed out, but is excluded from every total.
  BoolColumn get supersededByCloseout => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
