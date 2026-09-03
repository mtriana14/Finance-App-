import 'package:flutter/material.dart';

/// Design tokens from the spec, exposed as a [ThemeExtension] so light and dark
/// swap as one unit and no screen ever hard-codes a hex value.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.danger,
    required this.dangerLight,
    required this.success,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
  });

  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color accentLight;
  final Color danger;
  final Color dangerLight;
  final Color success;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;

  static const light = AppColors(
    primary: Color(0xFF1B6B4A),
    primaryLight: Color(0xFFE8F5EE),
    accent: Color(0xFFD4924F),
    accentLight: Color(0xFFFFF3E6),
    danger: Color(0xFFC0392B),
    dangerLight: Color(0xFFFDEDEB),
    success: Color(0xFF27AE60),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF7F6F3),
    textPrimary: Color(0xFF1A1D23),
    textSecondary: Color(0xFF6B7280),
    textDisabled: Color(0xFFB0B5BD),
    border: Color(0xFFE5E7EB),
  );

  static const dark = AppColors(
    primary: Color(0xFF3DBB7A),
    primaryLight: Color(0x1F3DBB7A),
    accent: Color(0xFFE8A85C),
    accentLight: Color(0x1AE8A85C),
    // Dark-mode danger/success are lightened so they clear WCAG AA on #1E2128.
    danger: Color(0xFFE8705F),
    dangerLight: Color(0x1FE8705F),
    success: Color(0xFF4ED08B),
    surface: Color(0xFF1E2128),
    background: Color(0xFF14171C),
    textPrimary: Color(0xFFE8E6E0),
    textSecondary: Color(0xFF9A9DA3),
    textDisabled: Color(0xFF6B7078),
    border: Color(0x14FFFFFF),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? accentLight,
    Color? danger,
    Color? dangerLight,
    Color? success,
    Color? surface,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      danger: danger ?? this.danger,
      dangerLight: dangerLight ?? this.dangerLight,
      success: success ?? this.success,
      surface: surface ?? this.surface,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerLight: Color.lerp(dangerLight, other.dangerLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
