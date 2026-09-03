import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: brightness == Brightness.light ? Colors.white : const Color(0xFF08130D),
      secondary: c.accent,
      onSecondary: brightness == Brightness.light ? Colors.white : const Color(0xFF1A1206),
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: 'Inter',
      extensions: [c],
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.heading(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      // No drop shadows anywhere: the spec trades them for a 1px border to
      // keep the GPU cost down on cheap phones.
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.cardRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: AppText.bodySmallMedium(color: c.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.cardRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: AppText.body(color: c.textDisabled),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.standard,
          vertical: Gap.compact + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sizes.cardRadius),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sizes.cardRadius),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sizes.cardRadius),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}
