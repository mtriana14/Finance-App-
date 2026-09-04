import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_entry.dart';
import '../../domain/models/ledger_kind.dart';
import '../../domain/services/ledger_math.dart';
import '../libreta/customer_detail_screen.dart';
import '../shell/app_shell.dart';
import 'export.dart';

enum HistorialFilter { todos, efectivo, qr, tarjeta, fiado }

extension on HistorialFilter {
  String get label => switch (this) {
        HistorialFilter.todos => 'Todos',
        HistorialFilter.efectivo => 'Efectivo',
        HistorialFilter.qr => 'QR',
        HistorialFilter.tarjeta => 'Tarjeta',
        HistorialFilter.fiado => 'Fiado',
      };

  /// Null means every channel. "Fiado" deliberately covers both directions:
  /// credit given and credit collected.
  Set<LedgerKind>? get kinds => switch (this) {
        HistorialFilter.todos => null,
        HistorialFilter.efectivo => {LedgerKind.cashSale},
        HistorialFilter.qr => {LedgerKind.qrSale},
        HistorialFilter.tarjeta => {LedgerKind.cardSale},
        HistorialFilter.fiado => {LedgerKind.fiadoIssued, LedgerKind.fiadoPayment},
      };
}

/// Screen 08 — the proof screen.
///
/// Every movement, in order, with the daily total spelled out so a merchant can
/// check the dashboard against the rows that produced it.
class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  HistorialFilter _filter = HistorialFilter.todos;
  DateTimeRange? _range;

  /// Entries rendered per day before the rest are summarised.
  static const _rowsPerDay = 50;

  /// How many days deep the list is loaded. Grows on "Ver más días"; the
  /// database only ever returns this many days.
  static const _dayStep = 12;
  int _visibleDays = _dayStep;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // A tap on the dashboard's sales card lands here scoped to today.
    final todayOnly = ref.watch(historialTodayOnlyProvider);
    final today = ref.watch(todayProvider).value ?? DateTime.now();
    final effectiveRange =
        todayOnly ? DateTimeRange(start: today, end: today) : _range;

    final page = ref.watch(historialProvider(HistorialQuery(
          kinds: _filter.kinds,
          from: effectiveRange?.start,
          to: effectiveRange?.end,
          dayLimit: _visibleDays,
        )));
    final entries = page.value?.entries ?? const <LedgerEntry>[];
    final hasMoreDays = page.value?.hasMoreDays ?? false;

    final shownDays = LedgerMath.groupByDay(entries);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          AppIconButton(
            icon: AppIcons.calendar,
            tooltip: 'Rango de fechas',
            color: effectiveRange != null ? c.primary : null,
            onPressed: () => _pickRange(context, todayOnly),
          ),
          _ExportMenu(kinds: _filter.kinds, range: effectiveRange),
          const SizedBox(width: Gap.micro),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            active: _filter,
            onChanged: (f) => setState(() {
              _filter = f;
              _visibleDays = _dayStep;
            }),
          ),
          if (effectiveRange != null)
            _RangeChip(
              range: effectiveRange,
              onClear: () {
                ref.read(historialTodayOnlyProvider.notifier).state = false;
                setState(() => _range = null);
              },
            ),
          Expanded(
            child: shownDays.isEmpty
                ? (page.isLoading
                    ? const SizedBox.shrink()
                    : _EmptyHistorial(
                        filtered:
                            _filter != HistorialFilter.todos || effectiveRange != null))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.standard, Gap.tight, Gap.standard, Gap.major),
                    itemCount: shownDays.length + (hasMoreDays ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= shownDays.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: Gap.standard),
                          child: AppButton(
                            label: 'Ver más días',
                            style: AppButtonStyle.outline,
                            onPressed: () => setState(() => _visibleDays += _dayStep),
                          ),
                        );
                      }
                      final day = shownDays[index];
                      return _DaySection(
                        day: day.day,
                        entries: day.entries.take(_rowsPerDay).toList(),
                        hiddenCount: day.entries.length - _rowsPerDay,
                        totalCents: day.totals.totalCents,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, bool todayOnly) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
      locale: const Locale('es'),
      helpText: 'Elige un rango',
      saveText: 'Listo',
    );
    if (picked == null) return;
    if (todayOnly) {
      ref.read(historialTodayOnlyProvider.notifier).state = false;
    }
    setState(() {
      _range = picked;
      _visibleDays = _dayStep;
    });
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onChanged});

  final HistorialFilter active;
  final ValueChanged<HistorialFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: Sizes.tapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.standard),
        itemCount: HistorialFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.tight),
        itemBuilder: (context, i) {
          final filter = HistorialFilter.values[i];
          final selected = filter == active;
          return Center(
            child: Material(
              color: selected ? c.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(filter),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? c.primary : c.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.standard, vertical: Gap.tight),
                    child: Text(
                      filter.label,
                      style: AppText.bodySmallMedium(
                        color: selected ? onPrimaryColor(context) : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.range, required this.onClear});

  final DateTimeRange range;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sameDay = Dates.businessDay(range.start) == Dates.businessDay(range.end);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, 0),
      child: Row(
        children: [
          AppIcon(AppIcons.calendar, size: 16, color: c.primary),
          const SizedBox(width: Gap.tight),
          Expanded(
            child: Text(
              sameDay
                  ? Dates.dayHeader(range.start)
                  : '${Dates.shortDay(range.start)} — ${Dates.shortDay(range.end)}',
              style: AppText.bodySmallMedium(color: c.primary),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(minimumSize: const Size(0, Sizes.tapTarget)),
            child: Text('Quitar filtro', style: AppText.bodySmall(color: c.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    required this.hiddenCount,
    required this.totalCents,
  });

  final DateTime day;
  final List<LedgerEntry> entries;
  final int hiddenCount;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Gap.standard, bottom: Gap.tight),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Dates.dayHeader(day),
                  style: AppText.bodySmallMedium(color: c.textPrimary),
                ),
              ),
              Text('Total: ', style: AppText.caption(color: c.textSecondary)),
              MoneyText(totalCents, style: AppText.moneySmall(), color: c.accent),
            ],
          ),
        ),
        Divider(color: c.border, height: 1),
        for (final entry in entries) _EntryRow(entry: entry),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: Gap.tight),
            child: Text(
              '$hiddenCount movimientos más en este día',
              style: AppText.caption(color: c.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFiadoIssued = entry.kind == LedgerKind.fiadoIssued;
    final replaced = entry.supersededByCloseout;

    // A fiado issued and a replaced entry are both shown for visibility, and
    // both are muted so it reads as "listed, not counted".
    final muted = isFiadoIssued || replaced;

    final icon = switch (entry.kind) {
      LedgerKind.cashSale => AppIcons.cash,
      LedgerKind.qrSale => AppIcons.qr,
      LedgerKind.cardSale => AppIcons.card,
      LedgerKind.fiadoIssued => AppIcons.arrowOut,
      LedgerKind.fiadoPayment => AppIcons.arrowIn,
    };

    final subtitleParts = <String>[
      if (replaced) 'Reemplazado por cierre del día',
      if (isFiadoIssued) 'No suma al total',
      if (entry.note != null && entry.note!.isNotEmpty && !entry.isCloseout) entry.note!,
    ];

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              Dates.time(entry.occurredAt),
              style: AppText.caption(color: muted ? c.textDisabled : c.textSecondary),
            ),
          ),
          AppIcon(icon, size: 18, color: muted ? c.textDisabled : c.textSecondary),
          const SizedBox(width: Gap.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.isCloseout ? 'Cierre del día' : entry.kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmallMedium(
                          color: muted ? c.textSecondary : c.textPrimary,
                        ),
                      ),
                    ),
                    if (entry.source.badge != null) ...[
                      const SizedBox(width: Gap.tight),
                      _SourceBadge(label: entry.source.badge!),
                    ],
                  ],
                ),
                if (entry.customerName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.customerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall(color: c.textSecondary),
                  ),
                ],
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(color: c.textDisabled),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.tight),
          MoneyText(
            entry.amountCents,
            style: AppText.moneyBody(),
            color: replaced
                ? c.textDisabled
                : isFiadoIssued
                    ? c.textSecondary
                    : c.textPrimary,
          ),
        ],
      ),
    );

    return Column(
      children: [
        if (entry.customerId != null)
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerDetailScreen(customerId: entry.customerId!),
              ),
            ),
            child: row,
          )
        else
          row,
        Divider(color: c.border, height: 1),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.primaryLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: AppText.caption(color: c.primary)),
    );
  }
}

/// Export covers everything matching the current filter, not just the days
/// scrolled into view — and it reads the ledger on demand rather than holding
/// a standing subscription to all of it.
class _ExportMenu extends ConsumerWidget {
  const _ExportMenu({required this.kinds, required this.range});

  final Set<LedgerKind>? kinds;
  final DateTimeRange? range;

  bool _matches(LedgerEntry e) {
    if (kinds != null && !kinds!.contains(e.kind)) return false;
    if (range != null) {
      final day = Dates.businessDay(e.occurredAt);
      if (day < Dates.businessDay(range!.start) || day > Dates.businessDay(range!.end)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: 'Exportar',
      color: c.surface,
      icon: AppIcon(AppIcons.share, size: 22, color: c.textPrimary),
      onSelected: (value) async {
        final all = await ref.read(ledgerRepositoryProvider).exportAll();
        final entries = all.where(_matches).toList();
        if (!context.mounted) return;
        if (entries.isEmpty) {
          showSnack(context, 'No hay movimientos para exportar');
          return;
        }
        try {
          if (value == 'csv') {
            await LedgerExport.shareCsv(entries);
          } else {
            await LedgerExport.shareSummary(entries, title: 'Resumen de ventas');
          }
        } catch (_) {
          if (context.mounted) {
            showSnack(context, 'No se pudo compartir el archivo', danger: true);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              AppIcon(AppIcons.download, size: 18, color: c.textSecondary),
              const SizedBox(width: Gap.compact),
              Text('Exportar CSV', style: AppText.bodySmall(color: c.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'summary',
          child: Row(
            children: [
              AppIcon(AppIcons.share, size: 18, color: c.textSecondary),
              const SizedBox(width: Gap.compact),
              Text('Compartir resumen', style: AppText.bodySmall(color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHistorial extends StatelessWidget {
  const _EmptyHistorial({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (filtered) {
      return EmptyState(
        illustration: AppIcon(AppIcons.filter, size: 64, color: c.textSecondary),
        title: 'Nada con este filtro',
        message: 'Prueba con otro canal o quita el rango de fechas.',
      );
    }
    return EmptyState(
      illustration: AppIcon(AppIcons.clock, size: 64, color: c.textSecondary),
      title: 'Aún no hay transacciones',
      message: 'Registra tu primera venta desde Inicio.',
      action: AppButton(
        label: 'Ir a Inicio',
        style: AppButtonStyle.outline,
        expand: false,
        onPressed: () => AppShell.goToInicio(context),
      ),
    );
  }
}
