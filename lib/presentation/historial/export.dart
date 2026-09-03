import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/models/ledger_entry.dart';
import '../../domain/models/ledger_kind.dart';
import '../../domain/services/ledger_math.dart';

/// CSV and WhatsApp exports.
///
/// Both are built from the same ledger rows the screens read, so an exported
/// file always reconciles with what the merchant saw.
abstract final class LedgerExport {
  static const _headers = [
    'fecha',
    'hora',
    'canal',
    'monto',
    'cuenta_como_venta',
    'nota',
    'cliente',
    'origen',
    'estado',
  ];

  static String toCsv(List<LedgerEntry> entries) {
    final buffer = StringBuffer()..writeln(_headers.join(','));
    for (final e in entries) {
      buffer.writeln([
        Dates.iso(e.occurredAt),
        Dates.time(e.occurredAt),
        e.kind.label,
        Money.bare(e.amountCents),
        // Spelled out so the file is self-explanatory: a fiado issued is money
        // lent, and does not belong in a revenue column.
        e.countsAsIncome ? 'si' : 'no',
        e.note ?? '',
        e.customerName ?? '',
        e.source.badge ?? 'manual',
        e.supersededByCloseout ? 'reemplazado por cierre del dia' : 'activo',
      ].map(_escape).join(','));
    }
    return buffer.toString();
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Plain text that renders cleanly in a WhatsApp message — no tables, no
  /// markdown, just aligned lines.
  static String toSummary(List<LedgerEntry> entries, {required String title}) {
    final days = LedgerMath.groupByDay(entries);
    final overall = LedgerMath.totals(entries);
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('');

    for (final day in days.take(31)) {
      buffer.writeln('${Dates.dayHeader(day.day)}: ${Money.format(day.totals.totalCents)}');
    }

    buffer
      ..writeln('')
      ..writeln('TOTAL: ${Money.format(overall.totalCents)}')
      ..writeln('  QR: ${Money.format(overall.qrCents)}')
      ..writeln('  Tarjeta: ${Money.format(overall.cardCents)}')
      ..writeln('  Efectivo: ${Money.format(overall.cashCents)}')
      ..writeln('  Cobros fiado: ${Money.format(overall.fiadoCollectedCents)}');

    if (overall.fiadoIssuedCents > 0) {
      buffer.writeln('');
      buffer.writeln(
          'Fiado dado (no cuenta como venta): ${Money.format(overall.fiadoIssuedCents)}');
    }
    return buffer.toString();
  }

  /// Writes the CSV to a temporary file and hands it to the system share sheet.
  static Future<void> shareCsv(List<LedgerEntry> entries, {String name = 'libreta'}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name-${Dates.iso(DateTime.now())}.csv');
    await file.writeAsString(toCsv(entries));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Historial de ventas'),
    );
  }

  static Future<void> shareSummary(List<LedgerEntry> entries, {required String title}) {
    return SharePlus.instance.share(ShareParams(text: toSummary(entries, title: title)));
  }
}
