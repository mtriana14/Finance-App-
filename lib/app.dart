import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'presentation/shell/app_shell.dart';

class LibretaApp extends ConsumerWidget {
  const LibretaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Before settings load on first frame, follow the system rather than
    // flashing a light screen at a merchant using a dark phone.
    final themeMode = ref.watch(settingsProvider).value?.themeMode ?? ThemeMode.system;

    return MaterialApp(
      title: 'Libreta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('es', 'EC')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Merchants set large system fonts. Honour that, but cap the scale so
        // a 40sp money readout can't push the save button off screen.
        final scaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
