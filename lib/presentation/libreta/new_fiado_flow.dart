import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../domain/models/customer.dart';
import '../../domain/services/ledger_math.dart';

/// Screen 06 — logging a fiado.
///
/// Target is four taps for an existing customer: pick them, tap an amount,
/// save. The note and the running summary share the amount step so nothing is
/// gated behind an extra screen.
Future<void> startNewFiado(BuildContext context, {Customer? customer}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => NewFiadoScreen(preselected: customer)),
  );
}

class NewFiadoScreen extends ConsumerStatefulWidget {
  const NewFiadoScreen({super.key, this.preselected});

  final Customer? preselected;

  @override
  ConsumerState<NewFiadoScreen> createState() => _NewFiadoScreenState();
}

class _NewFiadoScreenState extends ConsumerState<NewFiadoScreen> {
  late Customer? _customer = widget.preselected;
  final _noteController = TextEditingController();
  int _cents = 0;
  bool _saving = false;

  bool get _hasInput => _customer != null || _cents > 0 || _noteController.text.isNotEmpty;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// The X in the header abandons the whole flow, but never silently.
  Future<void> _close() async {
    if (!_hasInput) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await confirmSheet(
      context,
      title: '¿Descartar este fiado?',
      message: 'Lo que escribiste no se guardará.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
      destructive: true,
      icon: AppIcons.alert,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  /// Back steps to the customer picker without losing the amount already typed.
  void _back() {
    if (_customer != null && widget.preselected == null) {
      setState(() => _customer = null);
    } else {
      _close();
    }
  }

  Future<void> _save() async {
    final customer = _customer;
    if (customer == null || _cents <= 0 || _saving) return;
    setState(() => _saving = true);
    await ref.read(ledgerRepositoryProvider).addFiado(
          customerId: customer.id,
          amountCents: _cents,
          note: _noteController.text,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    showSavedSnack(context, 'Fiado registrado');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final onCustomerStep = _customer == null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: onCustomerStep
            ? null
            : AppIconButton(icon: AppIcons.chevronLeft, tooltip: 'Atrás', onPressed: _back),
        title: Text(onCustomerStep ? 'Nuevo fiado' : '¿Cuánto le fiaste?'),
        actions: [
          AppIconButton(icon: AppIcons.close, tooltip: 'Cancelar', onPressed: _close),
          const SizedBox(width: Gap.tight),
        ],
      ),
      body: onCustomerStep
          ? _CustomerPicker(onPick: (customer) => setState(() => _customer = customer))
          : _AmountStep(
              customer: _customer!,
              cents: _cents,
              noteController: _noteController,
              saving: _saving,
              onChanged: (value) => setState(() => _cents = value),
              onSave: _save,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — who
// ---------------------------------------------------------------------------

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker({required this.onPick});

  final ValueChanged<Customer> onPick;

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = ref.watch(customersProvider).value ?? const <Customer>[];
    final query = LedgerMath.normalizeName(_searchController.text);

    final matches = query.isEmpty
        ? all
        : all.where((x) => LedgerMath.normalizeName(x.name).contains(query)).toList();

    // With no search term, the most recent customers come first — those are
    // the ones a merchant fiados to again.
    final recentIds = (ref.watch(fiadoEntriesProvider).value ?? const [])
        .map((e) => e.customerId)
        .whereType<int>()
        .toList();
    final ordered = [...matches];
    if (query.isEmpty) {
      final rank = <int, int>{};
      for (var i = 0; i < recentIds.length; i++) {
        rank.putIfAbsent(recentIds[i], () => i);
      }
      ordered.sort((a, b) {
        final ra = rank[a.id] ?? 1 << 30;
        final rb = rank[b.id] ?? 1 << 30;
        return ra != rb ? ra.compareTo(rb) : a.name.compareTo(b.name);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, Gap.major),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: AppText.body(color: c.textPrimary),
          decoration: const InputDecoration(hintText: 'Buscar cliente...'),
        ),
        const SizedBox(height: Gap.compact),
        AppButton(
          label: 'Nuevo cliente',
          icon: AppIcons.plus,
          style: AppButtonStyle.outline,
          onPressed: () async {
            final created = await showNewCustomerSheet(
              context,
              ref,
              initialName: _searchController.text,
            );
            if (created != null) widget.onPick(created);
          },
        ),
        const SizedBox(height: Gap.section),
        if (ordered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Gap.major),
            child: Text(
              all.isEmpty
                  ? 'Aún no tienes clientes. Crea el primero arriba.'
                  : 'Ningún cliente coincide.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall(color: c.textSecondary),
            ),
          )
        else ...[
          Text(
            query.isEmpty ? 'CLIENTES RECIENTES' : 'RESULTADOS',
            style: AppText.caption(color: c.textSecondary),
          ),
          const SizedBox(height: Gap.compact),
          for (final customer in ordered)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.tight),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.compact, vertical: Gap.tight),
                onTap: () => widget.onPick(customer),
                child: Row(
                  children: [
                    AvatarCircle(customer.name, size: 40),
                    const SizedBox(width: Gap.compact),
                    Expanded(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMedium(color: c.textPrimary),
                      ),
                    ),
                    AppIcon(AppIcons.chevronRight, size: 20, color: c.textDisabled),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Creating a customer asks for a name and nothing else. Phone is optional; no
/// address, no ID.
Future<Customer?> showNewCustomerSheet(
  BuildContext context,
  WidgetRef ref, {
  String initialName = '',
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _NewCustomerSheet(initialName: initialName),
  );
}

class _NewCustomerSheet extends ConsumerStatefulWidget {
  const _NewCustomerSheet({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends ConsumerState<_NewCustomerSheet> {
  late final _nameController = TextEditingController(text: widget.initialName);
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = _nameController.text.trim();
    final existing = ref.watch(customersProvider).value ?? const <Customer>[];

    // Before creating a near-duplicate, offer the customer who already exists.
    final similar = LedgerMath.similarCustomers(name, existing);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Gap.standard,
          right: Gap.standard,
          top: Gap.compact,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.standard,
        ),
        child: SingleChildScrollView(
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
              Text('Nuevo cliente', style: AppText.subheading(color: c.textPrimary)),
              const SizedBox(height: Gap.standard),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: AppText.body(color: c.textPrimary),
                decoration: const InputDecoration(hintText: 'Nombre'),
              ),
              const SizedBox(height: Gap.compact),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppText.body(color: c.textPrimary),
                decoration: const InputDecoration(hintText: 'Teléfono (opcional)'),
              ),
              if (similar.isNotEmpty) ...[
                const SizedBox(height: Gap.standard),
                Text('¿Es esta persona?', style: AppText.bodySmallMedium(color: c.textPrimary)),
                const SizedBox(height: Gap.tight),
                for (final match in similar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.tight),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.compact, vertical: Gap.tight),
                      onTap: () => Navigator.of(context).pop(match),
                      child: Row(
                        children: [
                          AvatarCircle(match.name, size: 36),
                          const SizedBox(width: Gap.compact),
                          Expanded(
                            child: Text(match.name, style: AppText.bodyMedium(color: c.textPrimary)),
                          ),
                          Text('Usar', style: AppText.bodySmallMedium(color: c.primary)),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: Gap.section),
              AppButton(
                label: similar.isEmpty ? 'Crear cliente' : 'Crear de todas formas',
                large: true,
                onPressed: name.isEmpty
                    ? null
                    : () async {
                        final created = await ref.read(customerRepositoryProvider).create(
                              name: name,
                              phone: _phoneController.text,
                            );
                        if (context.mounted) Navigator.of(context).pop(created);
                      },
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — how much
// ---------------------------------------------------------------------------

class _AmountStep extends ConsumerWidget {
  const _AmountStep({
    required this.customer,
    required this.cents,
    required this.noteController,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final Customer customer;
  final int cents;
  final TextEditingController noteController;
  final bool saving;
  final ValueChanged<int> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final presets =
        ref.watch(settingsProvider).value?.presetAmountsCents ?? const [50, 100, 200, 500, 1000, 2000, 5000, 10000];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, Gap.standard),
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.compact, vertical: Gap.tight),
                child: Row(
                  children: [
                    AvatarCircle(customer.name, size: 36),
                    const SizedBox(width: Gap.compact),
                    Expanded(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMedium(color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.section),
              AmountDisplay(cents),
              const SizedBox(height: Gap.section),
              PresetGrid(
                presets: presets,
                onAdd: (value) => onChanged(cents + value),
                onOther: () async {
                  final entered = await showAmountKeypad(context,
                      title: '¿Cuánto le fiaste?', initialCents: cents);
                  if (entered != null) onChanged(entered);
                },
              ),
              const SizedBox(height: Gap.standard),
              NoteField(controller: noteController, placeholder: '¿Qué le vendiste?'),
              if (cents > 0) ...[
                const SizedBox(height: Gap.standard),
                AppCard(
                  color: c.accentLight,
                  borderColor: c.accent.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.arrowOut, size: 20, color: c.accent),
                      const SizedBox(width: Gap.compact),
                      Expanded(
                        child: Text(
                          '${customer.name} te debe',
                          style: AppText.bodySmall(color: c.textPrimary),
                        ),
                      ),
                      MoneyText(cents, style: AppText.moneyMedium(), color: c.accent),
                    ],
                  ),
                ),
              ],
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
                if (cents > 0)
                  AppButton(
                    label: 'Limpiar',
                    style: AppButtonStyle.text,
                    onPressed: () => onChanged(0),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
