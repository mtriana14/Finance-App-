import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';

enum AppButtonStyle { primary, outline, danger, text }

/// Every button in the app. Minimum height is the spec's 48dp tap target;
/// primary screen actions pass [large] for 56dp.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.large = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppIconData? icon;
  final bool large;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;

    final (Color bg, Color fg, Color? border) = switch (style) {
      AppButtonStyle.primary => (c.primary, _onPrimary(context), null),
      AppButtonStyle.danger => (c.danger, Colors.white, null),
      AppButtonStyle.outline => (Colors.transparent, c.primary, c.primary),
      AppButtonStyle.text => (Colors.transparent, c.textSecondary, null),
    };

    final height = large ? Sizes.primaryAction : Sizes.tapTarget;
    final radius = BorderRadius.circular(Sizes.cardRadius);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: 20, color: enabled ? fg : c.textDisabled),
          const SizedBox(width: Gap.tight),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button(color: enabled ? fg : c.textDisabled),
          ),
        ),
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: Material(
        color: enabled ? bg : (style == AppButtonStyle.primary ? c.border : Colors.transparent),
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: border != null
                  ? Border.all(color: enabled ? border : c.border, width: 1.4)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.standard),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }

  static Color _onPrimary(BuildContext context) => onPrimaryColor(context);
}

/// Foreground colour that sits on the primary green in either theme.
Color onPrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF08130D);

/// A 48dp-minimum icon-only tap target, for header actions.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.badge = false,
  });

  final AppIconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  /// Draws the unread dot used by the notification bell.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = SizedBox(
      width: Sizes.tapTarget,
      height: Sizes.tapTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AppIcon(icon, size: 22, color: color ?? c.textPrimary),
              if (badge)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
