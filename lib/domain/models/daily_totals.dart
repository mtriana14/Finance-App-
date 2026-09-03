import 'ledger_kind.dart';

/// The dashboard's hero number and its breakdown, computed together so they can
/// never disagree.
class DailyTotals {
  const DailyTotals({
    this.qrCents = 0,
    this.cardCents = 0,
    this.cashCents = 0,
    this.fiadoCollectedCents = 0,
    this.fiadoIssuedCents = 0,
    this.entryCount = 0,
  });

  final int qrCents;
  final int cardCents;
  final int cashCents;
  final int fiadoCollectedCents;

  /// Shown for context in Historial, deliberately absent from [totalCents].
  final int fiadoIssuedCents;

  final int entryCount;

  /// Ventas del día = QR + tarjeta + efectivo + cobros de fiado.
  /// Fiados issued are excluded by construction, not by a later subtraction.
  int get totalCents => qrCents + cardCents + cashCents + fiadoCollectedCents;

  int centsFor(SalesChannel channel) => switch (channel) {
        SalesChannel.qr => qrCents,
        SalesChannel.card => cardCents,
        SalesChannel.cash => cashCents,
        SalesChannel.fiadoCollected => fiadoCollectedCents,
      };

  bool get isEmpty => totalCents == 0 && fiadoIssuedCents == 0;

  DailyTotals operator +(DailyTotals other) => DailyTotals(
        qrCents: qrCents + other.qrCents,
        cardCents: cardCents + other.cardCents,
        cashCents: cashCents + other.cashCents,
        fiadoCollectedCents: fiadoCollectedCents + other.fiadoCollectedCents,
        fiadoIssuedCents: fiadoIssuedCents + other.fiadoIssuedCents,
        entryCount: entryCount + other.entryCount,
      );
}

/// One bar of the 7-day chart.
class DayBar {
  const DayBar({required this.day, required this.totalCents, required this.hasData});

  final DateTime day;
  final int totalCents;

  /// False for days before the merchant started using the app — those render
  /// as gray placeholders rather than as real $0 days.
  final bool hasData;
}
