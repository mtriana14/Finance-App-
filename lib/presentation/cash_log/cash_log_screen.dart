import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_pad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/submit_guard.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/ledger_kind.dart';
import '../../domain/services/ledger_math.dart';

/// Screen 04 — logging cash.
///
/// Two modes, and they are mutually exclusive by design: individual sales
/// accumulate through the day, or one end-of-day count replaces them. Letting
/// both stand would double-count the day.
class CashLogScreen extends ConsumerStatefulWidget {
  const CashLogScreen({super.key});

  @override
  ConsumerState<CashLogScreen> createState() => _CashLogScreenState();
}

class _CashLogScreenState extends ConsumerState<CashLogScreen>
    with SubmitGuard<CashLogScreen> {
  final _noteController = TextEditingController();
  int _cents = 0;
  bool _closeoutMode = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.chevronLeft,
          tooltip: 'Atrás',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_closeoutMode ? 'Cierre del día' : 'Registrar venta en efectivo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.standard),
            child: _ModeToggle(
              closeoutMode: _closeoutMode,
              onChanged: (value) => setState(() {
                _closeoutMode = value;
                _cents = 0;
              }),
            ),
          ),
          Expanded(
            child: _closeoutMode
                ? _CloseoutMode(onSaved: () => Navigator.of(context).pop())
                : _IndividualMode(
                    cents: _cents,
                    noteController: _noteController,
                    saving: submitting,
                    onChanged: (value) => setState(() => _cents = value),
                    onSave: _save,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_cents <= 0 || submitting) return;
    final ledger = ref.read(ledgerRepositoryProvider);
    final now = DateTime.now();

    // The spec's double-counting guard: a fiado settled in cash is recorded
    // once, on the customer's page. If the merchant is about to log the same
    // money again as a plain cash sale, ask before saving rather than quietly
    // inflating the day.
    final recent = await ledger.recentFiadoPayments(now: now);
    if (!mounted) return;
    final clash = LedgerMath.matchingRecentFiadoPayment(
      recentPayments: recent,
      amountCents: _cents,
      now: now,
    );
    if (clash != null) {
      final proceed = await confirmSheet(
        context,
        title: '¿Ya registraste esto como pago de fiado?',
        message:
            'Hace un momento registraste un cobro de fiado por ${Money.format(clash.amountCents)}. '
            'Si es el mismo dinero, no lo guardes otra vez.',
        confirmLabel: 'Es una venta distinta',
        cancelLabel: 'Ya lo registré',
        icon: AppIcons.alert,
      );
      if (!mounted) return;
      if (!proceed) {
        Navigator.of(context).pop();
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final saved = await submit(
      () => ledger.addSale(
        kind: LedgerKind.cashSale,
        amountCents: _cents,
        note: _noteController.text,
      ),
      failureMessage: 'No se pudo guardar la venta. Intenta de nuevo.',
    );
    if (!saved) return;

    navigator.pop();
    showSavedSnackOn(messenger, 'Venta guardada');
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.closeoutMode, required this.onChanged});

  final bool closeoutMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget segment(String label, bool selected, VoidCallback onTap) => Expanded(
          child: Material(
            color: selected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Sizes.cardRadius - 2),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Sizes.cardRadius - 2),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmallMedium(
                      color: selected ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(Gap.micro),
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Sizes.cardRadius),
      ),
      child: Row(
        children: [
          segment('Venta individual', !closeoutMode, () => onChanged(false)),
          segment('Cierre del día', closeoutMode, () => onChanged(true)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual sales
// ---------------------------------------------------------------------------

class _IndividualMode extends ConsumerWidget {
  const _IndividualMode({
    required this.cents,
    required this.noteController,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final int cents;
  final TextEditingController noteController;
  final bool saving;
  final ValueChanged<int> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets =
        ref.watch(settingsProvider).value?.presetAmountsCents ?? AppSettings.defaultPresets;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.standard),
            children: [
              AmountDisplay(
                cents,
                hint: cents == 0 ? 'Toca un monto para empezar' : null,
              ),
              const SizedBox(height: Gap.section),
              PresetGrid(
                presets: presets,
                onAdd: (value) => onChanged(cents + value),
                onOther: () async {
                  final entered = await showAmountKeypad(
                    context,
                    title: 'Monto de la venta',
                    initialCents: cents,
                  );
                  if (entered != null) onChanged(entered);
                },
                // Long-press rewrites a preset to whatever this merchant
                // actually sells.
                onEditPreset: (index, current) async {
                  final updated = await showAmountKeypad(
                    context,
                    title: 'Cambiar monto rápido',
                    initialCents: current,
                    confirmLabel: 'Guardar monto',
                  );
                  if (updated == null || updated <= 0) return;
                  final next = [...presets]..[index] = updated;
                  await ref.read(settingsRepositoryProvider).setPresets(next);
                },
              ),
              const SizedBox(height: Gap.standard),
              NoteField(controller: noteController),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, Gap.compact),
            child: Column(
              children: [
                AppButton(
                  label: 'Guardar',
                  large: true,
                  onPressed: cents > 0 && !saving ? onSave : null,
                ),
                AppButton(
                  label: 'Limpiar',
                  style: AppButtonStyle.text,
                  onPressed: cents > 0 ? () => onChanged(0) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// End-of-day reconciliation
// ---------------------------------------------------------------------------

class _CloseoutMode extends ConsumerStatefulWidget {
  const _CloseoutMode({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_CloseoutMode> createState() => _CloseoutModeState();
}

class _CloseoutModeState extends ConsumerState<_CloseoutMode>
    with SubmitGuard<_CloseoutMode> {
  int _drawerCents = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final floatCents = ref.watch(settingsProvider).value?.cashFloatCents ?? 0;
    final alreadyLogged = ref.watch(individualCashTodayProvider);
    final sales = LedgerMath.closeoutSales(drawerCents: _drawerCents, floatCents: floatCents);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.standard),
            children: [
              if (alreadyLogged > 0) ...[
                WarningBanner(
                  message:
                      'Ya registraste ${Money.format(alreadyLogged)} en ventas individuales hoy. '
                      'El cierre del día REEMPLAZA esas ventas, no se suma.',
                ),
                const SizedBox(height: Gap.standard),
              ],
              Text('¿Cuánto efectivo tienes en caja?',
                  style: AppText.subheading(color: c.textPrimary)),
              const SizedBox(height: Gap.section),
              AppCard(
                onTap: () async {
                  final entered = await showAmountKeypad(
                    context,
                    title: 'Efectivo en caja',
                    initialCents: _drawerCents,
                  );
                  if (entered != null) setState(() => _drawerCents = entered);
                },
                padding: const EdgeInsets.symmetric(vertical: Gap.section),
                child: AmountDisplay(
                  _drawerCents,
                  hint: _drawerCents == 0 ? 'Toca para ingresar el total' : null,
                ),
              ),
              const SizedBox(height: Gap.section),
              AppCard(
                child: Column(
                  children: [
                    _CalcRow(label: 'Efectivo en caja', cents: _drawerCents),
                    const SizedBox(height: Gap.tight),
                    _CalcRow(label: 'Fondo de caja', cents: -floatCents),
                    const SizedBox(height: Gap.compact),
                    Divider(color: c.border, height: 1),
                    const SizedBox(height: Gap.compact),
                    _CalcRow(label: 'Ventas en efectivo hoy', cents: sales, emphasis: true),
                  ],
                ),
              ),
              const SizedBox(height: Gap.compact),
              Text(
                floatCents == 0
                    ? 'Tu fondo de caja está en \$0.00. Puedes cambiarlo en Perfil.'
                    : 'Se resta tu fondo de caja de ${Money.format(floatCents)}, configurado en Perfil.',
                style: AppText.bodySmall(color: c.textSecondary),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, Gap.compact),
            child: AppButton(
              label: 'Guardar cierre',
              large: true,
              onPressed: _drawerCents > 0 && !submitting ? _save : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final floatCents = ref.read(settingsProvider).value?.cashFloatCents ?? 0;
    final sales = LedgerMath.closeoutSales(drawerCents: _drawerCents, floatCents: floatCents);
    final alreadyLogged = ref.read(individualCashTodayProvider);

    if (alreadyLogged > 0) {
      final ok = await confirmSheet(
        context,
        title: 'El cierre reemplaza tus ventas de hoy',
        message:
            'Las ${Money.format(alreadyLogged)} que registraste una por una se reemplazarán por '
            '${Money.format(sales)}. Quedarán en el historial como reemplazadas.',
        confirmLabel: 'Guardar cierre',
        icon: AppIcons.alert,
      );
      if (!ok || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final saved = await submit(
      () => ref.read(ledgerRepositoryProvider).saveCloseout(
            day: DateTime.now(),
            drawerCents: _drawerCents,
            floatCents: floatCents,
          ),
      failureMessage: 'No se pudo guardar el cierre. Intenta de nuevo.',
    );
    if (!saved) return;

    showSavedSnackOn(messenger, 'Cierre guardado');
    widget.onSaved();
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow({required this.label, required this.cents, this.emphasis = false});

  final String label;
  final int cents;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasis
                ? AppText.bodyMedium(color: c.textPrimary)
                : AppText.bodySmall(color: c.textSecondary),
          ),
        ),
        MoneyText(
          cents,
          signed: cents < 0,
          style: emphasis ? AppText.moneyMedium() : AppText.moneyBody(),
          color: emphasis ? c.accent : c.textPrimary,
        ),
      ],
    );
  }
}
