
import 'package:flutter/material.dart';

/// Inter and JetBrains Mono ship as variable fonts, so every weight comes from
/// one file per family. [FontVariation] drives the real `wght` axis;
/// [FontWeight] is kept in sync so fallback rendering still looks right.
TextStyle _inter(double size, int weight,
    {double? height, double? spacing, Color? color}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    height: height,
    letterSpacing: spacing,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

TextStyle _mono(double size, int weight, {Color? color}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    // Tabular figures keep columns of money aligned as digits change.
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

abstract final class AppText {
  // Display / headers — 20-28sp bold.
  static TextStyle display({Color? color}) => _inter(28, 700, height: 1.2, color: color);
  static TextStyle title({Color? color}) => _inter(22, 700, height: 1.25, color: color);
  static TextStyle heading({Color? color}) => _inter(20, 600, height: 1.3, color: color);
  static TextStyle subheading({Color? color}) => _inter(17, 600, height: 1.35, color: color);

  // Body — 16sp regular, 1.5 line height.
  static TextStyle body({Color? color}) => _inter(16, 400, height: 1.5, color: color);
  static TextStyle bodyMedium({Color? color}) => _inter(16, 500, height: 1.5, color: color);
  static TextStyle bodySmall({Color? color}) => _inter(14, 400, height: 1.45, color: color);
  static TextStyle bodySmallMedium({Color? color}) => _inter(14, 500, height: 1.45, color: color);

  /// Caption — 12sp medium, wide tracking, used uppercase for labels.
  static TextStyle caption({Color? color}) =>
      _inter(12, 500, height: 1.35, spacing: 0.48, color: color);

  static TextStyle label({Color? color}) =>
      _inter(13, 500, height: 1.3, spacing: 0.2, color: color);

  // Money — monospace, tabular.
  static TextStyle moneyHero({Color? color}) => _mono(36, 500, color: color);
  static TextStyle moneyKeypad({Color? color}) => _mono(40, 500, color: color);
  static TextStyle moneyLarge({Color? color}) => _mono(28, 500, color: color);
  static TextStyle moneyMedium({Color? color}) => _mono(20, 500, color: color);
  static TextStyle moneyBody({Color? color}) => _mono(16, 500, color: color);
  static TextStyle moneySmall({Color? color}) => _mono(14, 500, color: color);

  static TextStyle button({Color? color}) => _inter(16, 600, height: 1.2, color: color);
}
