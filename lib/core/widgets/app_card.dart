import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 12dp radius, 1px border, no drop shadow — the spec trades elevation for a
/// border to keep the GPU cost down on a $120 phone.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.standard),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(Sizes.cardRadius);
    return Material(
      color: color ?? c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? c.border, width: borderWidth),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
