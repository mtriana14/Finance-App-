import 'ledger_kind.dart';

/// A plain, database-free ledger row. Everything that computes a total works on
/// these, so the business rules can be tested without spinning up SQLite.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.occurredAt,
    this.note,
    this.customerId,
    this.customerName,
    this.source = EntrySource.manual,
    this.isCloseout = false,
    this.supersededByCloseout = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? occurredAt;

  final int id;
  final LedgerKind kind;
  final int amountCents;
  final DateTime occurredAt;
  final String? note;
  final int? customerId;
  final String? customerName;
  final EntrySource source;

  /// True for the single entry produced by an end-of-day reconciliation.
  final bool isCloseout;

  /// True once an end-of-day reconciliation has replaced this entry. Kept for
  /// the audit trail, shown grayed out, and excluded from every total.
  final bool supersededByCloseout;

  final DateTime createdAt;

  /// A row only counts toward a total if it is income and has not been
  /// superseded by a day-close.
  bool get countsAsIncome => kind.isIncome && !supersededByCloseout;

  /// Entries can be deleted by mistake-correction only within 24h of logging.
  bool deletableAt(DateTime now) => now.difference(createdAt) < const Duration(hours: 24);

  LedgerEntry copyWith({bool? supersededByCloseout, String? customerName}) => LedgerEntry(
        id: id,
        kind: kind,
        amountCents: amountCents,
        occurredAt: occurredAt,
        note: note,
        customerId: customerId,
        customerName: customerName ?? this.customerName,
        source: source,
        isCloseout: isCloseout,
        supersededByCloseout: supersededByCloseout ?? this.supersededByCloseout,
        createdAt: createdAt,
      );
}
