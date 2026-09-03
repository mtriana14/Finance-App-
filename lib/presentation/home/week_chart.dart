import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/daily_totals.dart';

/// Seven bars, oldest to newest, today in accent copper.
///
/// Days from before the merchant started using the app render as short gray
/// placeholders rather than as $0 bars — a flat zero would read as "I sold
/// nothing that day", which isn't what happened.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.bars});

  final List<DayBar> bars;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (bars.isEmpty) return const SizedBox(height: 120);

    final maxCents = bars.fold<int>(0, (m, b) => b.totalCents > m ? b.totalCents : m);
    // A flat scale when nothing has been sold yet, so the axis doesn't collapse.
    final maxY = maxCents <= 0 ? 1.0 : maxCents / 100;
    final placeholderY = maxY * 0.06;

    return SizedBox(
      height: 132,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.15,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.textPrimary,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bar = bars[group.x];
                if (!bar.hasData) {
                  return BarTooltipItem(
                    'Sin registros',
                    AppText.caption(color: c.surface),
                  );
                }
                return BarTooltipItem(
                  Money.format(bar.totalCents),
                  AppText.moneySmall(color: c.surface),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= bars.length) return const SizedBox.shrink();
                  final bar = bars[index];
                  final isToday = index == bars.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: Gap.tight),
                    child: Text(
                      Dates.weekdayInitial(bar.day),
                      style: AppText.caption(
                        color: isToday ? c.accent : c.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: bars[i].hasData
                        ? (bars[i].totalCents / 100).clamp(placeholderY, double.infinity)
                        : placeholderY,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    color: !bars[i].hasData
                        ? c.border
                        : i == bars.length - 1
                            ? c.accent
                            : c.primary.withValues(alpha: 0.35),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
