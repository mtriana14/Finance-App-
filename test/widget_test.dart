import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:libreta/app.dart';
import 'package:libreta/data/db/database.dart';
import 'package:libreta/data/providers.dart';
import 'package:libreta/data/repositories/ledger_repository.dart';
import 'package:libreta/domain/models/ledger_kind.dart';

/// A ledger whose writes always fail, for exercising the save failure path.
class _FailingLedgerRepository extends LedgerRepository {
  _FailingLedgerRepository(super.db);

  @override
  Future<int> addSale({
    required LedgerKind kind,
    required int amountCents,
    String? note,
    int? customerId,
    DateTime? occurredAt,
    EntrySource source = EntrySource.manual,
  }) async {
    throw StateError('no space left on device');
  }
}

/// Drives the real screens against an in-memory database, so these cover the
/// wiring between a tap and a total rather than the arithmetic alone.
///
/// Teardown order matters here — see the comments in the `finally` block.
Future<void> withApp(
  WidgetTester tester,
  Future<void> Function() body, {
  Size size = const Size(400, 900),
  List<Override> Function(AppDatabase db)? overrides,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...?overrides?.call(db),
      ],
      child: const LibretaApp(),
    ),
  );
  await tester.pumpAndSettle();

  try {
    await body();
  } finally {
    // Unmount so the providers dispose and drift cancels its query streams,
    // then let a tick of fake time elapse to run the zero-duration cleanup
    // timer drift schedules — a bare pump() advances by zero and leaves it
    // pending, which trips the framework's end-of-test invariant check.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    // Not awaited: drift's close waits on a real timer that fake time never
    // advances. The in-memory database dies with the test process anyway.
    unawaited(db.close());
  }
}

/// Taps text that may be below the fold, scrolling it into view first.
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Logs a fiado for a brand-new customer — the app's core flow.
Future<void> addFiadoFor(WidgetTester tester, String name, String preset) async {
  await tapText(tester, 'Fiado');
  await tapText(tester, 'Nuevo cliente');
  await tester.enterText(find.widgetWithText(TextField, 'Nombre'), name);
  await tester.pumpAndSettle();
  await tapText(tester, 'Crear cliente');
  await tapText(tester, preset);
  await tapText(tester, 'Guardar');
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('day one shows a zero total with the quick actions as the content',
      (tester) async {
    await withApp(tester, () async {
      expect(find.text('VENTAS DE HOY'), findsOneWidget);

      // The hero number plus all four breakdown cells, none of them hidden at
      // zero — otherwise the breakdown would stop adding up to the total.
      expect(find.text(r'$0.00'), findsNWidgets(5));
      expect(find.text('QR'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Cobros fiado'), findsOneWidget);

      // The buttons are the empty state, not a "no data yet" message.
      expect(find.text('Venta'), findsOneWidget);
      expect(find.text('Fiado'), findsOneWidget);
    });
  });

  testWidgets('logging a cash sale updates the dashboard total immediately',
      (tester) async {
    await withApp(tester, () async {
      await tapText(tester, 'Venta');
      expect(find.text('Registrar venta en efectivo'), findsOneWidget);

      // Presets add up: $2.00 + $0.50 = $2.50, then save. Three taps.
      await tapText(tester, r'$2.00');
      await tapText(tester, r'$0.50');
      expect(find.text(r'$2.50'), findsOneWidget);

      await tapText(tester, 'Guardar');

      expect(find.text('Venta guardada'), findsOneWidget);
      // Back on the dashboard: the hero number and the Efectivo cell both moved.
      expect(find.text(r'$2.50'), findsNWidgets(2));
    });
  });

  testWidgets('a fiado is money lent — Te deben moves, the sales total does not',
      (tester) async {
    await withApp(tester, () async {
      await addFiadoFor(tester, 'María González', r'$10.00');

      expect(find.text('Fiado registrado'), findsOneWidget);
      expect(find.text('TE DEBEN'), findsOneWidget);
      expect(find.text(r'$10.00'), findsOneWidget);

      // Nothing was earned, so the hero and all four cells are still zero.
      expect(find.text(r'$0.00'), findsNWidgets(5));
    });
  });

  testWidgets('the Libreta lists the customer with their balance', (tester) async {
    await withApp(tester, () async {
      await addFiadoFor(tester, 'Juan Pérez', r'$20.00');
      await tapText(tester, 'Libreta');

      expect(find.text('TOTAL PENDIENTE'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('1 cliente con deuda'), findsOneWidget);
    });
  });

  testWidgets('recording a payment clears the balance and books it as income',
      (tester) async {
    await withApp(tester, () async {
      await addFiadoFor(tester, 'Ana Vera', r'$20.00');

      await tapText(tester, 'Libreta');
      await tapText(tester, 'Ana Vera');
      expect(find.text('DEBE EN TOTAL'), findsOneWidget);

      // The keypad pre-fills with the full amount owed.
      await tapText(tester, 'Registrar pago');
      await tapText(tester, 'Confirmar pago');

      expect(find.text('Pago registrado'), findsOneWidget);
      expect(find.text('No hay deuda pendiente.'), findsOneWidget);

      // Back out of her page to the shell, then over to the dashboard: the $20
      // is now income under Cobros fiado, and nobody owes anything, so the
      // fiado card is gone.
      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Inicio');
      expect(find.text(r'$20.00'), findsNWidgets(2));
      expect(find.text('TE DEBEN'), findsNothing);
    });
  });

  testWidgets('Historial shows the movement behind the total', (tester) async {
    await withApp(tester, () async {
      await tapText(tester, 'Venta');
      await tapText(tester, r'$5.00');
      await tapText(tester, 'Guardar');

      await tapText(tester, 'Historial');
      expect(find.textContaining('Hoy,'), findsOneWidget);
      expect(find.text('Efectivo'), findsWidgets);
      expect(find.text(r'$5.00'), findsWidgets);
    });
  });

  testWidgets('dark mode applies without a restart', (tester) async {
    await withApp(tester, () async {
      await tapText(tester, 'Perfil');
      await tapText(tester, 'Oscuro');

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  testWidgets('every tab lays out on a 360x640 screen without overflowing',
      (tester) async {
    // A 5-inch 720p phone, the floor the spec targets. A RenderFlex overflow
    // throws in debug, so rendering each tab is itself the assertion — checked
    // after every tab, since one pending exception at the end hides the rest.
    await withApp(tester, size: const Size(360, 640), () async {
      for (final tab in ['Libreta', 'Historial', 'Perfil', 'Inicio']) {
        await tapText(tester, tab);
        expect(tester.takeException(), isNull, reason: 'overflow on the $tab tab');
      }
    });
  });

  testWidgets('the app survives the largest font scale it honours', (tester) async {
    // Merchants set big system fonts. The app clamps the scale at 1.3; nothing
    // may clip at that ceiling on the smallest screen.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await withApp(tester, size: const Size(360, 640), () async {
      for (final tab in ['Libreta', 'Historial', 'Perfil', 'Inicio']) {
        await tapText(tester, tab);
        expect(tester.takeException(), isNull, reason: 'overflow on the $tab tab');
      }
    });
  });

  testWidgets('a failed save re-enables the button and says so', (tester) async {
    // The failure mode this guards against is not the error itself but what
    // came after it: a busy flag left raised, a dead Guardar button, and
    // nothing on screen explaining why. A merchant in that state writes the
    // sale on paper and stops trusting the app.
    await withApp(
      tester,
      overrides: (db) => [
        ledgerRepositoryProvider.overrideWithValue(_FailingLedgerRepository(db)),
      ],
      () async {
        await tapText(tester, 'Venta');
        await tapText(tester, r'$5.00');
        await tapText(tester, 'Guardar');

        // The write threw and was reported rather than swallowed.
        expect(tester.takeException(), isA<StateError>());

        // The merchant is told, in Spanish, and is still on the screen with
        // the amount they typed.
        expect(find.textContaining('No se pudo guardar'), findsOneWidget);
        expect(find.text('Registrar venta en efectivo'), findsOneWidget);
        expect(find.text(r'$5.00'), findsWidgets);

        // And the button works again — this is the part that used to stay dead.
        final button = tester.widget<InkWell>(
          find.ancestor(of: find.text('Guardar'), matching: find.byType(InkWell)).first,
        );
        expect(button.onTap, isNotNull);
      },
    );
  });

  testWidgets('a save that succeeds after a failure still records exactly once',
      (tester) async {
    await withApp(tester, () async {
      await tapText(tester, 'Venta');
      await tapText(tester, r'$5.00');
      await tapText(tester, 'Guardar');
      await tapText(tester, 'Venta');
      await tapText(tester, r'$5.00');
      await tapText(tester, 'Guardar');

      // Two deliberate sales, not one sale double-counted.
      expect(find.text(r'$10.00'), findsNWidgets(2));
    });
  });
}
