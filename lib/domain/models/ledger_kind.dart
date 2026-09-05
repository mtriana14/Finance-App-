/// Every movement the app records lives in one ledger table; this is what
/// distinguishes them.
///
/// The enum index is persisted, so entries may only ever be appended.
enum LedgerKind {
  /// Cash sale, logged by hand on the Cash Log screen.
  cashSale,

  /// QR sale (Deuna). Phase 2 syncs these; v1 has no source for them.
  qrSale,

  /// Card sale (PayPhone). Phase 2 syncs these.
  cardSale,

  /// Credit extended to a customer. Money lent out — never income.
  fiadoIssued,

  /// A customer paying down their fiado. This *is* income, on the day it is
  /// received.
  fiadoPayment,
}

/// The kinds that are money earned. Stated as a list of what counts, never as
/// "everything except fiadoIssued".
///
/// The difference matters the day someone appends a kind. An exclusion test
/// answers "yes, income" for a refund, an adjustment or a chargeback the
/// moment it exists, and nothing fails — the trend line just quietly starts
/// reporting money going out as money coming in. With this set, a new kind is
/// not income until somebody writes it down here.
const Set<LedgerKind> incomeKinds = {
  LedgerKind.cashSale,
  LedgerKind.qrSale,
  LedgerKind.cardSale,
  LedgerKind.fiadoPayment,
};

extension LedgerKindX on LedgerKind {
  /// The single rule the dashboard total rests on: a fiado issued is money
  /// lent, not money earned.
  bool get isIncome => incomeKinds.contains(this);

  bool get isFiado => this == LedgerKind.fiadoIssued || this == LedgerKind.fiadoPayment;

  String get label => switch (this) {
        LedgerKind.cashSale => 'Efectivo',
        LedgerKind.qrSale => 'QR Deuna',
        LedgerKind.cardSale => 'PayPhone',
        LedgerKind.fiadoIssued => 'Fiado dado',
        LedgerKind.fiadoPayment => 'Cobro fiado',
      };
}

/// Where a row came from. v1 only ever writes [manual]; the others exist so the
/// Phase 2 sync has somewhere to land without a migration.
enum EntrySource { manual, deuna, payphone }

extension EntrySourceX on EntrySource {
  String? get badge => switch (this) {
        EntrySource.manual => null,
        EntrySource.deuna => 'Deuna',
        EntrySource.payphone => 'PayPhone',
      };
}

/// The four buckets the dashboard breakdown shows. They must sum to the hero
/// number, which is why fiado *issued* has no bucket here.
enum SalesChannel { qr, card, cash, fiadoCollected }

extension SalesChannelX on SalesChannel {
  String get label => switch (this) {
        SalesChannel.qr => 'QR',
        SalesChannel.card => 'Tarjeta',
        SalesChannel.cash => 'Efectivo',
        SalesChannel.fiadoCollected => 'Cobros fiado',
      };
}
