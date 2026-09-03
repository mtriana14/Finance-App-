import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Spanish month and weekday names, loaded once so every date format is
  // synchronous afterwards.
  await initializeDateFormatting('es');
  runApp(const ProviderScope(child: LibretaApp()));
}
