import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:libreta/domain/models/ledger_entry.dart';
import 'package:libreta/domain/models/ledger_kind.dart';
import 'package:libreta/presentation/historial/export.dart';

LedgerEntry entry(
  LedgerKind kind,
  int cents, {
  String? note,
  String? customerName,
  DateTime? at,
}) =>
    LedgerEntry(
      id: 1,
      kind: kind,
      amountCents: cents,
      occurredAt: at ?? DateTime(2026, 9, 2, 14, 32),
      note: note,
      customerId: customerName == null ? null : 1,
      customerName: customerName,
    );

void main() {
  // Dates formats in Spanish, which intl refuses to do until the locale data
  // is loaded.
  setUpAll(() => initializeDateFormatting('es'));

  group('CSV export', () {
    test('writes a header and one row per entry', () {
      final csv = LedgerExport.toCsv([
        entry(LedgerKind.cashSale, 2250, note: 'almuerzos'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'fecha,hora,canal,monto,cuenta_como_venta,nota,cliente,origen,estado');
      expect(lines[1], startsWith('2026-09-02,14:32,Efectivo,22.50,si,almuerzos,'));
    });

    test('marks a fiado issued as not counting toward sales', () {
      final csv = LedgerExport.toCsv([
        entry(LedgerKind.fiadoIssued, 1500, customerName: 'María González'),
      ]);
      expect(csv, contains('Fiado dado,15.00,no,'));
      expect(csv, contains('María González'));
    });

    test('quotes fields containing a comma or a quote', () {
      final csv = LedgerExport.toCsv([
        entry(LedgerKind.cashSale, 500, note: 'pan, huevos y "leche"'),
      ]);
      expect(csv, contains('"pan, huevos y ""leche"""'));
    });

    test('neutralises spreadsheet formulas in merchant-entered text', () {
      // A customer name is dictated by the customer, and the finished file is
      // meant to be shared. Nothing in it may evaluate when opened.
      final csv = LedgerExport.toCsv([
        entry(
          LedgerKind.fiadoIssued,
          1500,
          customerName: '=HYPERLINK("https://evil.example","María")',
          note: '@SUM(A1:A9)',
        ),
      ]);

      // No cell begins a formula: each dangerous value is pinned to text.
      expect(csv, isNot(contains(',=HYPERLINK')));
      expect(csv, isNot(contains(',@SUM')));
      expect(csv, contains("'@SUM(A1:A9)"));
      expect(csv, contains('"\'=HYPERLINK(""https://evil.example"",""María"")"'));
    });

    test('covers every formula trigger, not just the equals sign', () {
      for (final payload in ['=1+1', '+1+1', '-1+1', '@A1', '\tcmd', '\rcmd']) {
        final csv = LedgerExport.toCsv([
          entry(LedgerKind.cashSale, 100, note: payload),
        ]);
        expect(csv, contains("'$payload"), reason: 'unescaped trigger: $payload');
      }
    });

    test('leaves ordinary values untouched', () {
      final csv = LedgerExport.toCsv([
        entry(LedgerKind.cashSale, 12345, note: 'pan'),
      ]);
      // Amounts stay plain numbers so a spreadsheet can still sum the column.
      expect(csv, contains(',123.45,'));
      expect(csv, contains(',pan,'));
      expect(csv, isNot(contains("'123.45")));
    });
  });

  group('WhatsApp summary', () {
    test('reconciles to the same four channels the dashboard shows', () {
      final summary = LedgerExport.toSummary([
        entry(LedgerKind.qrSale, 4500),
        entry(LedgerKind.cardSale, 3250),
        entry(LedgerKind.cashSale, 3500),
        entry(LedgerKind.fiadoPayment, 1500),
        entry(LedgerKind.fiadoIssued, 1500),
      ], title: 'Resumen de ventas');

      expect(summary, contains(r'TOTAL: $127.50'));
      expect(summary, contains(r'QR: $45.00'));
      expect(summary, contains(r'Tarjeta: $32.50'));
      expect(summary, contains(r'Efectivo: $35.00'));
      expect(summary, contains(r'Cobros fiado: $15.00'));
      // Listed for context, and labelled as not being a sale.
      expect(summary, contains(r'Fiado dado (no cuenta como venta): $15.00'));
    });
  });
}
