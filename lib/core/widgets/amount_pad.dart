import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/money.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// The large amount readout that sits above every entry pad.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay(this.cents, {super.key, this.hint, this.color});

  final int cents;
  final String? hint;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Text(
          Money.format(cents),
          textAlign: TextAlign.center,
          style: AppText.moneyKeypad(color: color ?? (cents == 0 ? c.textDisabled : c.textPrimary)),
        ),
        if (hint != null) ...[
          const SizedBox(height: Gap.tight),
          Text(hint!, textAlign: TextAlign.center, style: AppText.bodySmall(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// The 3x3 quick-amount grid.
///
/// Tapping a preset *adds* to the running total, so $2.50 is "$2.00, $0.50,
/// Guardar" — three taps, which is the spec's speed target. The ninth cell is
/// always "Otro"; the other eight are the merchant's own, editable by long
/// press.
class PresetGrid extends StatelessWidget {
  const PresetGrid({
    super.key,
    required this.presets,
    required this.onAdd,
    required this.onOther,
    this.onEditPreset,
  });

  final List<int> presets;
  final ValueChanged<int> onAdd;
  final VoidCallback onOther;

  /// Long-press handler. Null in flows where presets aren't customisable.
  final void Function(int index, int currentCents)? onEditPreset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = Gap.compact;
        final cellWidth = (constraints.maxWidth - spacing * 2) / 3;
        // 64dp per the spec, but never taller than a third of a short screen.
        final cellHeight = cellWidth < 64 ? 56.0 : 64.0;

        Widget cell(Widget child, {VoidCallback? onTap, VoidCallback? onLongPress, bool accent = false}) {
          return SizedBox(
            width: cellWidth,
            height: cellHeight,
            child: Material(
              color: accent ? c.primaryLight : c.surface,
              borderRadius: BorderRadius.circular(Sizes.cardRadius),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(Sizes.cardRadius),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Sizes.cardRadius),
                    border: Border.all(color: accent ? c.primary : c.border, width: accent ? 1.4 : 1),
                  ),
                  child: Center(child: child),
                ),
              ),
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < presets.length; i++)
              cell(
                Text(Money.format(presets[i]), style: AppText.moneyMedium(color: c.textPrimary)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAdd(presets[i]);
                },
                onLongPress: onEditPreset == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onEditPreset!(i, presets[i]);
                      },
              ),
            cell(
              Text('Otro', style: AppText.bodyMedium(color: c.primary)),
              onTap: onOther,
              accent: true,
            ),
          ],
        );
      },
    );
  }
}

/// A keypad, not a keyboard.
///
/// Digits shift in from the right the way a till does — 2, 5, 0 makes $2.50 —
/// which avoids asking a merchant to find the decimal point on a system
/// keyboard, and makes a wrong tap one backspace away from fixed.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget key(Widget child, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Gap.micro),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(Sizes.cardRadius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Sizes.cardRadius),
                child: Ink(
                  height: Sizes.primaryAction,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Sizes.cardRadius),
                    border: Border.all(color: c.border),
                  ),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        );

    Widget digit(int n) => key(
          Text('$n', style: AppText.moneyLarge(color: c.textPrimary)),
          () {
            HapticFeedback.selectionClick();
            onDigit(n);
          },
        );

    Widget row(List<Widget> children) => Row(children: children);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit(1), digit(2), digit(3)]),
        row([digit(4), digit(5), digit(6)]),
        row([digit(7), digit(8), digit(9)]),
        row([
          key(Text('00', style: AppText.moneyLarge(color: c.textPrimary)), () {
            HapticFeedback.selectionClick();
            onDigit(0);
            onDigit(0);
          }),
          digit(0),
          key(AppIcon(AppIcons.chevronLeft, size: 22, color: c.textSecondary), () {
            HapticFeedback.selectionClick();
            onBackspace();
          }),
        ]),
      ],
    );
  }
}

/// Bottom sheet wrapping [NumericKeypad]. Returns cents, or null if dismissed.
Future<int?> showAmountKeypad(
  BuildContext context, {
  required String title,
  int initialCents = 0,
  int? maxCents,
  String? maxHint,
  String confirmLabel = 'Listo',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _KeypadSheet(
      title: title,
      initialCents: initialCents,
      maxCents: maxCents,
      maxHint: maxHint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _KeypadSheet extends StatefulWidget {
  const _KeypadSheet({
    required this.title,
    required this.initialCents,
    required this.maxCents,
    required this.maxHint,
    required this.confirmLabel,
  });

  final String title;
  final int initialCents;
  final int? maxCents;
  final String? maxHint;
  final String confirmLabel;

  @override
  State<_KeypadSheet> createState() => _KeypadSheetState();
}

class _KeypadSheetState extends State<_KeypadSheet> {
  late int _cents = widget.initialCents;

  /// No artificial ceiling on a sale — some merchants sell high-value goods —
  /// but the accumulator is bounded so it can't overflow.
  static const _hardCap = 99999999;

  void _digit(int n) {
    final next = _cents * 10 + n;
    if (next > _hardCap) return;
    setState(() => _cents = next);
  }

  void _backspace() => setState(() => _cents = _cents ~/ 10);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = widget.maxCents;
    final overMax = max != null && _cents > max;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Gap.standard,
          right: Gap.standard,
          top: Gap.compact,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.standard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: Gap.standard),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            Text(widget.title, style: AppText.subheading(color: c.textPrimary)),
            const SizedBox(height: Gap.standard),
            AmountDisplay(
              _cents,
              color: overMax ? c.danger : null,
              hint: overMax ? widget.maxHint : null,
            ),
            const SizedBox(height: Gap.section),
            NumericKeypad(onDigit: _digit, onBackspace: _backspace),
            const SizedBox(height: Gap.standard),
            AppButton(
              label: widget.confirmLabel,
              large: true,
              onPressed: _cents == 0 || overMax ? null : () => Navigator.of(context).pop(_cents),
            ),
            const SizedBox(height: Gap.tight),
            AppButton(
              label: 'Cancelar',
              style: AppButtonStyle.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional, collapsible note. Same 80-character limit everywhere it appears.
class NoteField extends StatefulWidget {
  const NoteField({
    super.key,
    required this.controller,
    this.placeholder = 'Agregar nota...',
    this.label,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? label;

  @override
  State<NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<NoteField> {
  late bool _open = widget.controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: AppIcon(AppIcons.plus, size: 18, color: c.primary),
          label: Text(widget.placeholder, style: AppText.bodySmallMedium(color: c.primary)),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, Sizes.tapTarget),
            padding: const EdgeInsets.symmetric(horizontal: Gap.tight),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppText.label(color: c.textSecondary)),
          const SizedBox(height: Gap.tight),
        ],
        TextField(
          controller: widget.controller,
          maxLength: 80,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.body(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            counterStyle: AppText.caption(color: c.textDisabled),
          ),
        ),
      ],
    );
  }
}
