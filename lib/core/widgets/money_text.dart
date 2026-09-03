import 'package:flutter/material.dart';

import '../format/money.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Money is always monospace, always tabular, always right-aligned in a list.
/// Routing every amount through one widget is what keeps that true.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.color,
    this.signed = false,
    this.align = TextAlign.right,
  });

  final int cents;
  final TextStyle? style;
  final Color? color;
  final bool signed;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      signed ? Money.signed(cents) : Money.format(cents),
      textAlign: align,
      style: (style ?? AppText.moneyBody()).copyWith(color: color ?? context.colors.textPrimary),
    );
  }
}

/// Uppercase 12sp caption, used above every hero number.
class CaptionLabel extends StatelessWidget {
  const CaptionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.caption(color: color ?? context.colors.textSecondary),
    );
  }
}
