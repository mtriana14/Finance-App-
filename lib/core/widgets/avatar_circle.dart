import 'package:flutter/material.dart';

import '../../domain/services/ledger_math.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// First letter of the name on a colored circle.
///
/// The color is derived from a hash of the normalised name, so a customer keeps
/// the same circle forever — across sessions, and regardless of how the
/// merchant capitalised or accented it that day.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle(this.name, {super.key, this.size = 44});

  final String name;
  final double size;

  /// Muted tints that hold contrast against dark text in both themes.
  static const _palette = <Color>[
    Color(0xFF2E7D5B),
    Color(0xFF3D6B9E),
    Color(0xFFB0703A),
    Color(0xFF8A5A9E),
    Color(0xFF2F8E8E),
    Color(0xFFA6603F),
    Color(0xFF5C7A3D),
    Color(0xFF9E4F63),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final base = _palette[LedgerMath.avatarPaletteIndex(trimmed, _palette.length)];
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Same hue in both themes; the tint is lightened on dark backgrounds so
        // white text keeps its contrast ratio.
        color: dark ? Color.alphaBlend(base.withValues(alpha: 0.85), Colors.black) : base,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: AppText.subheading(color: Colors.white).copyWith(fontSize: size * 0.4),
      ),
    );
  }
}

/// Empty-state block: a stroke illustration, a headline and one line of help.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget illustration;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: 0.55, child: illustration),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: AppText.subheading(color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppText.bodySmall(color: c.textSecondary)),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
