import 'dart:io';

// drift also exports an `isNull`, which collides with the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreta/data/db/database.dart';
import 'package:libreta/domain/models/ledger_kind.dart';
import 'package:libreta/domain/services/ledger_math.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The v1 schema, written out by hand as it shipped — before `voided_at` and
/// `voided_reason` existed.
///
/// This is the migration a merchant who already has a month of fiado in the
/// app will run. Getting it wrong does not throw an error they would notice;
/// it loses the record of who owes them money. So the test builds a real v1
/// database on disk, puts real rows in it, and opens the current code on top.
const _v1LedgerEntries = '''
CREATE TABLE ledger_entries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  kind INTEGER NOT NULL,
  amount_cents INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL,
  business_day INTEGER NOT NULL,
  note TEXT NULL,
  customer_id INTEGER NULL REFERENCES customers(id) ON DELETE CASCADE,
  source INTEGER NOT NULL DEFAULT 0,
  is_closeout INTEGER NOT NULL DEFAULT 0 CHECK (is_closeout IN (0, 1)),
  superseded_by_closeout INTEGER NOT NULL DEFAULT 0
    CHECK (superseded_by_closeout IN (0, 1)),
  created_at INTEGER NOT NULL
)''';

const _v1Customers = '''
CREATE TABLE customers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NULL,
  search_key TEXT NOT NULL,
  created_at INTEGER NOT NULL
)''';

const _v1Settings = '''
CREATE TABLE settings (
  "key" TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY ("key")
)''';

int _epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
int _day(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

void main() {
  late File file;

  setUp(() {
    file = File('${Directory.systemTemp.createTempSync('libreta_mig').path}/app.db');
  });

  tearDown(() {
    if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
  });

  /// Builds a v1 database holding one customer with an outstanding fiado and
  /// a cash sale, then stamps it as schema version 1.
  void seedV1() {
    final db = sqlite3.sqlite3.open(file.path);
    db
      ..execute(_v1Customers)
      ..execute(_v1LedgerEntries)
      ..execute(_v1Settings);

    final now = DateTime(2026, 9, 2, 10);
    db.execute(
      'INSERT INTO customers (id, name, phone, search_key, created_at) '
      'VALUES (1, ?, NULL, ?, ?)',
      ['María González', 'maria gonzalez', _epoch(now)],
    );
    db.execute(
      'INSERT INTO ledger_entries '
      '(kind, amount_cents, occurred_at, business_day, note, customer_id, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        LedgerKind.fiadoIssued.index,
        4500,
        _epoch(now),
        _day(now),
        'víveres',
        1,
        _epoch(now),
      ],
    );
    db.execute(
      'INSERT INTO ledger_entries '
      '(kind, amount_cents, occurred_at, business_day, created_at) VALUES (?, ?, ?, ?, ?)',
      [LedgerKind.cashSale.index, 2250, _epoch(now), _day(now), _epoch(now)],
    );
    db.execute('PRAGMA user_version = 1');
    db.dispose();
  }

  test('a v1 database upgrades to v2 without losing anything', () async {
    seedV1();

    final db = AppDatabase(NativeDatabase(file));
    // Opening runs the migration.
    final entries = await db.select(db.ledgerEntries).get();

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 2, reason: 'migration ran to completion');
    expect(entries.length, 2, reason: 'the merchant kept both rows');

    final fiado = entries.firstWhere((e) => e.kind == LedgerKind.fiadoIssued);
    expect(fiado.amountCents, 4500);
    expect(fiado.note, 'víveres');
    expect(fiado.customerId, 1);

    // The new columns exist and read as "never voided" for pre-existing rows.
    expect(entries.every((e) => e.voidedAt == null), isTrue);
    expect(entries.every((e) => e.voidedReason == null), isTrue);

    // And the money still adds up to what it did before the upgrade.
    final domain = [for (final row in entries) row.toDomain()];
    expect(LedgerMath.totals(domain).totalCents, 2250);
    expect(LedgerMath.totals(domain).fiadoIssuedCents, 4500);

    await db.close();
  });

  test('the upgraded database can then void a row', () async {
    seedV1();

    final db = AppDatabase(NativeDatabase(file));
    final row = (await db.select(db.ledgerEntries).get())
        .firstWhere((e) => e.kind == LedgerKind.cashSale);

    await (db.update(db.ledgerEntries)..where((t) => t.id.equals(row.id))).write(
      LedgerEntriesCompanion(
        voidedAt: Value(DateTime(2026, 9, 2, 11)),
        voidedReason: const Value('Me equivoqué en el monto'),
      ),
    );

    final after = (await db.select(db.ledgerEntries).get())
        .firstWhere((e) => e.id == row.id)
        .toDomain();
    expect(after.isVoided, isTrue);
    expect(after.voidedReason, 'Me equivoqué en el monto');
    expect(after.countsInTotals, isFalse);

    await db.close();
  });

  test('a fresh install lands on v2 directly', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.into(db.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            kind: LedgerKind.cashSale,
            amountCents: 100,
            occurredAt: DateTime(2026, 9, 2),
            businessDay: 20260902,
            createdAt: DateTime(2026, 9, 2),
          ),
        );
    final entry = (await db.select(db.ledgerEntries).get()).single;
    expect(entry.voidedAt, isNull);
    expect(db.schemaVersion, 2);
    await db.close();
  });
}
