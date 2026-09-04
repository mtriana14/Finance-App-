import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../domain/models/daily_totals.dart';
import '../../domain/models/ledger_kind.dart';
import '../cash_log/cash_log_screen.dart';
import '../libreta/new_fiado_flow.dart';
import '../shell/app_shell.dart';
import 'week_chart.dart';

/// Screen 03 — the dashboard.
///
/// It answers one question in two seconds: how is my business doing today. It
/// reads only local data, so it is on screen immediately.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider).value;
    final totals = ref.watch(todayTotalsProvider);
    final trend = ref.watch(trendProvider);
    final owed = ref.watch(outstandingTotalProvider);
    final debtorCount = ref.watch(balancesProvider).length;
    final today = ref.watch(todayProvider).value ?? DateTime.now();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.major),
          children: [
            _GreetingBar(name: settings?.greetingName ?? 'comerciante', date: today),
            const SizedBox(height: Gap.standard),
            _TodayCard(
              totals: totals,
              trend: trend,
              onTap: () => AppShell.goToHistorial(context, todayOnly: true),
            ),
            const SizedBox(height: Gap.standard),
            _WeekSection(),
            const SizedBox(height: Gap.section),
            _QuickActions(),
            if (owed > 0) ...[
              const SizedBox(height: Gap.standard),
              _FiadoSummaryCard(owedCents: owed, customerCount: debtorCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreetingBar extends StatelessWidget {
  const _GreetingBar({required this.name, required this.date});

  final String name;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // 48dp is the floor the spec asks for, not a ceiling: two lines of text at
    // a merchant's chosen font scale are routinely taller than that, and a
    // fixed height clips them.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.tapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.tight),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(color: c.textPrimary),
                  ),
                  Text(
                    Dates.greetingDate(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero card. The four breakdown figures are rendered from the same
/// [DailyTotals] that produced the big number, so they cannot drift apart.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.totals, required this.trend, required this.onTap});

  final DailyTotals totals;
  final double? trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.standard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CaptionLabel('Ventas de hoy'),
              AppIcon(AppIcons.chevronRight, size: 18, color: c.textDisabled),
            ],
          ),
          const SizedBox(height: Gap.tight),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    totals.totalCents,
                    style: AppText.moneyHero(),
                    color: c.accent,
                    align: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(width: Gap.compact),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _TrendChip(trend),
              ),
            ],
          ),
          const SizedBox(height: Gap.standard),
          Divider(color: c.border, height: 1),
          const SizedBox(height: Gap.compact),
          // All four categories, always — a hidden $0 would make the breakdown
          // stop adding up to the number above it.
          Row(
            children: [
              for (final channel in SalesChannel.values)
                Expanded(
                  child: _BreakdownCell(
                    channel: channel,
                    cents: totals.centsFor(channel),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCell extends StatelessWidget {
  const _BreakdownCell({required this.channel, required this.cents});

  final SalesChannel channel;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = switch (channel) {
      SalesChannel.qr => AppIcons.qr,
      SalesChannel.card => AppIcons.card,
      SalesChannel.cash => AppIcons.cash,
      SalesChannel.fiadoCollected => AppIcons.arrowIn,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 16, color: c.textSecondary),
        const SizedBox(height: Gap.tight),
        Text(
          channel.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.format(cents),
            style: AppText.moneySmall(
              color: cents > 0 ? c.textPrimary : c.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip(this.trend);

  final double? trend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (trend == null) {
      return Text('sin datos de ayer', style: AppText.caption(color: c.textDisabled));
    }
    final up = trend! >= 0;
    final color = trend! == 0 ? c.textSecondary : (up ? c.success : c.danger);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(up ? AppIcons.arrowUp : AppIcons.arrowDown, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          '${Money.percent(trend!.abs())} vs ayer',
          style: AppText.caption(color: color),
        ),
      ],
    );
  }
}

class _WeekSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bars = ref.watch(weekBarsProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CaptionLabel('Últimos 7 días'),
          const SizedBox(height: Gap.standard),
          WeekChart(bars: bars),
          const SizedBox(height: Gap.tight),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => AppShell.goToHistorial(context),
              style: TextButton.styleFrom(minimumSize: const Size(0, Sizes.tapTarget)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ver todo',
                      style: AppText.bodySmallMedium(color: context.colors.primary)),
                  const SizedBox(width: Gap.micro),
                  AppIcon(AppIcons.chevronRight, size: 16, color: context.colors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On an empty day-one dashboard these buttons *are* the content — the spec is
/// explicit that a "no data yet" empty state teaches the merchant nothing.
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Venta',
            icon: AppIcons.plus,
            large: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CashLogScreen()),
            ),
          ),
        ),
        const SizedBox(width: Gap.compact),
        Expanded(
          child: AppButton(
            label: 'Fiado',
            icon: AppIcons.plus,
            large: true,
            style: AppButtonStyle.outline,
            onPressed: () => startNewFiado(context),
          ),
        ),
      ],
    );
  }
}

class _FiadoSummaryCard extends StatelessWidget {
  const _FiadoSummaryCard({required this.owedCents, required this.customerCount});

  final int owedCents;
  final int customerCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => AppShell.goToLibreta(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.accentLight, shape: BoxShape.circle),
            child: Center(child: AppIcon(AppIcons.book, size: 22, color: c.accent)),
          ),
          const SizedBox(width: Gap.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CaptionLabel('Te deben'),
                const SizedBox(height: 2),
                MoneyText(
                  owedCents,
                  style: AppText.moneyMedium(),
                  color: c.accent,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 2),
                Text(
                  customerCount == 1
                      ? '1 cliente con deuda pendiente'
                      : '$customerCount clientes con deuda pendiente',
                  style: AppText.bodySmall(color: c.textSecondary),
                ),
              ],
            ),
          ),
          AppIcon(AppIcons.chevronRight, size: 20, color: c.textDisabled),
        ],
      ),
    );
  }
}
