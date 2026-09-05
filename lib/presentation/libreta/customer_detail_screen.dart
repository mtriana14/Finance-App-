import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_pad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_entry.dart';
import '../../domain/models/ledger_kind.dart';
import '../../domain/services/ledger_math.dart';
import 'new_fiado_flow.dart';

/// Screen 07 — one customer's whole fiado history.
class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  /// A long-standing customer can have hundreds of entries; the list starts at
  /// 30 and grows on demand rather than building them all.
  static const _pageSize = 30;
  int _visible = _pageSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final balance = ref.watch(customerBalanceProvider(widget.customerId));
    final entries = ref.watch(customerEntriesProvider(widget.customerId)).value ?? const [];

    if (balance == null) {
      // The customer was deleted while this screen was open.
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(leading: const _BackButton()),
        body: Center(
          child: Text('Cliente no encontrado', style: AppText.bodySmall(color: c.textSecondary)),
        ),
      );
    }

    final customer = balance.customer;
    final statement = LedgerMath.statement(entries);
    final shown = statement.take(_visible).toList();
    final owed = balance.balanceCents;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const _BackButton(),
        title: Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.standard),
              itemCount: shown.length + 2 + (shown.length < statement.length ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(name: customer.name, phone: customer.phone, owedCents: owed);
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Gap.compact),
                    child: Text('MOVIMIENTOS', style: AppText.caption(color: c.textSecondary)),
                  );
                }
                final row = index - 2;
                if (row >= shown.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Gap.compact),
                    child: AppButton(
                      label: 'Ver más',
                      style: AppButtonStyle.outline,
                      onPressed: () => setState(() => _visible += _pageSize),
                    ),
                  );
                }
                return _StatementRow(
                  entry: shown[row].entry,
                  balanceCents: shown[row].balanceCents,
                  onVoid: () => _confirmVoid(shown[row].entry),
                );
              },
            ),
          ),
          _Actions(
            owedCents: owed,
            onPay: owed > 0 ? () => _registerPayment(owed) : null,
            onNewFiado: () => startNewFiado(context, customer: customer),
          ),
        ],
      ),
    );
  }

  /// Payments default to the full amount owed and can be lowered to any part
  /// of it, but never raised above it.
  Future<void> _registerPayment(int owedCents) async {
    final amount = await showAmountKeypad(
      context,
      title: 'Registrar pago',
      initialCents: owedCents,
      maxCents: owedCents,
      maxHint: 'No puede ser mayor a la deuda de ${Money.format(owedCents)}',
      confirmLabel: 'Confirmar pago',
    );
    if (amount == null || amount <= 0) return;
    if (!mounted) return;

    if (amount < owedCents) {
      final ok = await confirmSheet(
        context,
        title: 'Pago parcial: ${Money.format(amount)}',
        message: 'Queda ${Money.format(owedCents - amount)} pendiente.',
        confirmLabel: 'Confirmar pago',
        icon: AppIcons.arrowIn,
      );
      if (!ok) return;
    }

    await ref.read(ledgerRepositoryProvider).addFiadoPayment(
          customerId: widget.customerId,
          amountCents: amount,
        );
    if (!mounted) return;
    showSavedSnack(context, 'Pago registrado');
  }

  Future<void> _confirmVoid(LedgerEntry entry) async {
    final reason = await showVoidReasonSheet(context);
    if (reason == null || !mounted) return;

    final voided =
        await ref.read(ledgerRepositoryProvider).voidEntry(entry.id, reason: reason);
    if (!mounted) return;
    if (voided) {
      showSnack(context, 'Registro anulado');
    } else {
      showSnack(context, 'Solo puedes anular registros del último día', danger: true);
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: AppIcons.chevronLeft,
      tooltip: 'Atrás',
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.phone, required this.owedCents});

  final String name;
  final String? phone;
  final int owedCents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.section),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                AvatarCircle(name, size: 52),
                const SizedBox(width: Gap.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subheading(color: c.textPrimary),
                      ),
                      if (phone != null && phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            AppIcon(AppIcons.phone, size: 14, color: c.textSecondary),
                            const SizedBox(width: Gap.micro),
                            Text(phone!, style: AppText.bodySmall(color: c.textSecondary)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.standard),
            Divider(color: c.border, height: 1),
            const SizedBox(height: Gap.standard),
            const CaptionLabel('Debe en total'),
            const SizedBox(height: Gap.micro),
            MoneyText(
              owedCents,
              style: AppText.moneyLarge(),
              color: owedCents > 0 ? c.accent : c.success,
              align: TextAlign.center,
            ),
            if (owedCents == 0) ...[
              const SizedBox(height: Gap.micro),
              Text('Sin deuda pendiente', style: AppText.bodySmall(color: c.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.entry,
    required this.balanceCents,
    required this.onVoid,
  });

  final LedgerEntry entry;
  final int balanceCents;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPayment = entry.kind == LedgerKind.fiadoPayment;
    final voided = entry.isVoided;
    // A voided row can no longer be voided again, so it loses the swipe.
    final voidable = !voided && entry.correctableAt(DateTime.now());

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            voided
                ? AppIcons.close
                : (isPayment ? AppIcons.check : AppIcons.arrowOut),
            size: 18,
            color: voided ? c.textDisabled : (isPayment ? c.success : c.textSecondary),
          ),
          const SizedBox(width: Gap.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPayment ? 'Pagó' : 'Fiado',
                  style: AppText.bodySmallMedium(
                    color: voided
                        ? c.textDisabled
                        : (isPayment ? c.success : c.textPrimary),
                  ).copyWith(
                    decoration: voided ? TextDecoration.lineThrough : null,
                    decorationColor: c.textDisabled,
                  ),
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall(
                        color: voided ? c.textDisabled : c.textSecondary),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  voided
                      ? 'Anulado · ${entry.voidedReason ?? 'sin motivo'}'
                      : Dates.shortDay(entry.occurredAt),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(color: voided ? c.danger : c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.tight),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isPayment ? '−${Money.format(entry.amountCents)}' : Money.format(entry.amountCents),
                style: AppText.moneyBody(
                  color: voided
                      ? c.textDisabled
                      : (isPayment ? c.success : c.textPrimary),
                ).copyWith(
                  decoration: voided ? TextDecoration.lineThrough : null,
                  decorationColor: c.textDisabled,
                ),
              ),
              const SizedBox(height: 2),
              Text('saldo ${Money.format(balanceCents)}',
                  style: AppText.caption(color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );

    if (!voidable) {
      return Column(
        children: [row, Divider(color: c.border, height: 1)],
      );
    }

    // Swipe to correct a mistake, available for 24 hours after logging. The
    // row is never dismissed — confirmDismiss always returns false — because
    // voiding leaves it in place rather than removing it from the list.
    return Column(
      children: [
        Dismissible(
          key: ValueKey('entry-${entry.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            onVoid();
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Gap.standard),
            color: c.dangerLight,
            child: AppIcon(AppIcons.close, size: 20, color: c.danger),
          ),
          child: row,
        ),
        Divider(color: c.border, height: 1),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.owedCents, required this.onPay, required this.onNewFiado});

  final int owedCents;
  final VoidCallback? onPay;
  final VoidCallback onNewFiado;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.compact, Gap.standard, Gap.compact),
          child: Column(
            children: [
              AppButton(
                label: 'Registrar pago',
                large: true,
                icon: AppIcons.arrowIn,
                onPressed: onPay,
              ),
              if (owedCents == 0)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.tight),
                  child: Text('No hay deuda pendiente.',
                      style: AppText.bodySmall(color: c.textSecondary)),
                ),
              const SizedBox(height: Gap.tight),
              AppButton(
                label: 'Nuevo fiado',
                style: AppButtonStyle.outline,
                icon: AppIcons.plus,
                onPressed: onNewFiado,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
