import 'package:drift/drift.dart';

import '../../domain/models/customer.dart';
import '../../domain/services/ledger_math.dart';
import '../db/database.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final AppDatabase _db;

  Stream<List<Customer>> watchAll() {
    final query = _db.select(_db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => [for (final r in rows) r.toDomain()]);
  }

  Future<List<Customer>> all() async {
    final rows = await (_db.select(_db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return [for (final r in rows) r.toDomain()];
  }

  /// Recently active customers, for the top of the new-fiado picker.
  Future<List<Customer>> recent({int limit = 5}) async {
    final lastSeen = _db.ledgerEntries.occurredAt.max();
    final query = _db.select(_db.customers).join([
      innerJoin(_db.ledgerEntries, _db.ledgerEntries.customerId.equalsExp(_db.customers.id)),
    ])
      ..addColumns([lastSeen])
      ..groupBy([_db.customers.id])
      ..orderBy([OrderingTerm.desc(lastSeen)])
      ..limit(limit);
    final rows = await query.get();
    return [for (final r in rows) r.readTable(_db.customers).toDomain()];
  }

  /// Accent-insensitive search against the stored search key, so "maria"
  /// finds "María" without a table scan in Dart.
  Stream<List<Customer>> search(String term) {
    final key = LedgerMath.normalizeName(term);
    if (key.isEmpty) return watchAll();
    final query = _db.select(_db.customers)
      ..where((t) => t.searchKey.like('%$key%'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => [for (final r in rows) r.toDomain()]);
  }

  Future<Customer> create({required String name, String? phone}) async {
    final trimmed = name.trim();
    final now = DateTime.now();
    final id = await _db.into(_db.customers).insert(
          CustomersCompanion.insert(
            name: trimmed,
            phone: Value(_cleanPhone(phone)),
            searchKey: LedgerMath.normalizeName(trimmed),
            createdAt: now,
          ),
        );
    return Customer(id: id, name: trimmed, phone: _cleanPhone(phone), createdAt: now);
  }

  Future<void> update({required int id, required String name, String? phone}) {
    final trimmed = name.trim();
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: Value(trimmed),
        phone: Value(_cleanPhone(phone)),
        searchKey: Value(LedgerMath.normalizeName(trimmed)),
      ),
    );
  }

  Future<Customer?> byId(int id) async {
    final row = await (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Cascades to the customer's ledger entries via the foreign key.
  Future<void> delete(int id) =>
      (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAll() => _db.delete(_db.customers).go();

  static String? _cleanPhone(String? raw) {
    final t = raw?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
