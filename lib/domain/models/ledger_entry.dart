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
    this.voidedAt,
    this.voidedReason,
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

  /// When the merchant voided this entry as a mistake, and the reason they
  /// gave. Null on a live row. A voided row is never removed: it stays in the
  /// statement, struck through, so the correction is part of the record
  /// instead of erasing it.
  final DateTime? voidedAt;
  final String? voidedReason;

  final DateTime createdAt;

  bool get isVoided => voidedAt != null;

  /// Whether this row contributes to any arithmetic — a total, a balance, a
  /// chart. Both ways a row can be struck from the books are handled here, so
  /// no caller has to remember both.
  bool get countsInTotals => !supersededByCloseout && !isVoided;

  /// A row counts as income only if it is an income kind and still stands.
  bool get countsAsIncome => kind.isIncome && countsInTotals;

  /// Entries can be deleted by mistake-correction only within 24h of logging.
  bool deletableAt(DateTime now) => now.difference(createdAt) < const Duration(hours: 24);

  LedgerEntry copyWith({
    bool? supersededByCloseout,
    String? customerName,
    DateTime? voidedAt,
    String? voidedReason,
  }) =>
      LedgerEntry(
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
        voidedAt: voidedAt ?? this.voidedAt,
        voidedReason: voidedReason ?? this.voidedReason,
        createdAt: createdAt,
      );
}
