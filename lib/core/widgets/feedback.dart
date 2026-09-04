import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// Confirmation of a save without looking at the screen: a short vibration
/// plus a snackbar that never blocks navigation.
void showSavedSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showSavedSnackOn(messenger, message, colors: context.colors);
}

/// The same confirmation, addressed to a messenger captured earlier.
///
/// A save usually pops its route, and a popped route's context can no longer
/// find the messenger. Capturing it before navigating is what keeps the
/// confirmation from being silently dropped.
void showSavedSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  AppColors? colors,
}) {
  HapticFeedback.mediumImpact();
  _show(messenger, message, colors: colors);
}

void showSnack(BuildContext context, String message, {bool danger = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  _show(messenger, message, danger: danger, colors: context.colors);
}

void _show(
  ScaffoldMessengerState messenger,
  String message, {
  bool danger = false,
  AppColors? colors,
}) {
  final palette = colors ?? AppColors.light;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.bodySmallMedium(color: Colors.white)),
        backgroundColor: danger ? palette.danger : palette.textPrimary,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(Gap.standard),
      ),
    );
}

/// Bottom sheet confirmation — the spec asks for sheets rather than centre
/// modals because they are easier to reach with a thumb and easier to dismiss.
///
/// Every destructive action routes through here.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  AppIconData? icon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final c = context.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.compact, Gap.standard, Gap.standard),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Gap.section),
                  decoration:
                      BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (icon != null) ...[
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: destructive ? c.dangerLight : c.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(icon, size: 24, color: destructive ? c.danger : c.primary),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.standard),
              ],
              Text(title, textAlign: TextAlign.center, style: AppText.subheading(color: c.textPrimary)),
              if (message != null) ...[
                const SizedBox(height: Gap.tight),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bodySmall(color: c.textSecondary),
                ),
              ],
              const SizedBox(height: Gap.section),
              AppButton(
                label: confirmLabel,
                large: true,
                style: destructive ? AppButtonStyle.danger : AppButtonStyle.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: Gap.tight),
              AppButton(
                label: cancelLabel,
                style: AppButtonStyle.text,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// A short inline warning strip. Used for the two double-counting guards.
class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.message, this.tone = WarningTone.caution});

  final String message;
  final WarningTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      WarningTone.caution => (c.accentLight, c.accent),
      WarningTone.danger => (c.dangerLight, c.danger),
      WarningTone.info => (c.primaryLight, c.primary),
    };
    return Container(
      padding: const EdgeInsets.all(Gap.compact),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Sizes.cardRadius),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(tone == WarningTone.info ? AppIcons.info : AppIcons.alert, size: 20, color: fg),
          const SizedBox(width: Gap.compact),
          Expanded(
            child: Text(message, style: AppText.bodySmall(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

enum WarningTone { caution, danger, info }
