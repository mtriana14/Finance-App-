import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../domain/models/customer.dart';
import '../../domain/services/ledger_math.dart';
import 'customer_detail_screen.dart';
import 'new_fiado_flow.dart';

/// Screen 05 — the customer list.
///
/// This is the app's wedge: it replaces a paper notebook that gets wet, gets
/// lost and gets argued about, and it is the reason a merchant opens the app
/// tomorrow.
class LibretaScreen extends ConsumerStatefulWidget {
  const LibretaScreen({super.key});

  @override
  ConsumerState<LibretaScreen> createState() => _LibretaScreenState();
}

class _LibretaScreenState extends ConsumerState<LibretaScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final balances = ref.watch(balancesProvider);
    final total = ref.watch(outstandingTotalProvider);
    final sortByRecent = ref.watch(settingsProvider).value?.sortByRecent ?? false;

    final query = LedgerMath.normalizeName(_searchController.text);
    final visible = query.isEmpty
        ? balances
        : balances
            .where((b) => LedgerMath.normalizeName(b.customer.name).contains(query))
            .toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: AppText.body(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar cliente...',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text('Mi Libreta'),
        actions: [
          if (balances.isNotEmpty)
            AppIconButton(
              icon: AppIcons.sort,
              tooltip: sortByRecent ? 'Ordenar por deuda' : 'Ordenar por más reciente',
              onPressed: () =>
                  ref.read(settingsRepositoryProvider).setSortByRecent(!sortByRecent),
            ),
          AppIconButton(
            icon: _searching ? AppIcons.close : AppIcons.search,
            tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
          const SizedBox(width: Gap.tight),
        ],
      ),
      floatingActionButton: SizedBox(
        width: Sizes.primaryAction,
        height: Sizes.primaryAction,
        child: FloatingActionButton(
          onPressed: () => startNewFiado(context),
          backgroundColor: c.primary,
          foregroundColor: onPrimaryColor(context),
          elevation: 2,
          shape: const CircleBorder(),
          tooltip: 'Nuevo fiado',
          child: AppIcon(AppIcons.plus, size: 26, color: onPrimaryColor(context)),
        ),
      ),
      body: balances.isEmpty
          ? _EmptyLibreta(onAdd: () => startNewFiado(context))
          : Column(
              children: [
                _SummaryBar(totalCents: total, customerCount: balances.length),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Ningún cliente coincide con la búsqueda',
                            style: AppText.bodySmall(color: c.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          // Lazily built, so a merchant with hundreds of
                          // customers scrolls without jank.
                          padding: const EdgeInsets.fromLTRB(
                              Gap.standard, Gap.compact, Gap.standard, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Gap.tight),
                          itemBuilder: (context, i) => _CustomerRow(balance: visible[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalCents, required this.customerCount});

  final int totalCents;
  final int customerCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.tight, Gap.standard, Gap.standard),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CaptionLabel('Total pendiente'),
          const SizedBox(height: Gap.micro),
          MoneyText(totalCents, style: AppText.moneyLarge(), color: c.accent, align: TextAlign.left),
          const SizedBox(height: Gap.micro),
          Text(
            customerCount == 1 ? '1 cliente con deuda' : '$customerCount clientes con deuda',
            style: AppText.bodySmall(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.balance});

  final CustomerBalance balance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final overdue = balance.isOverdue(now);
    final radius = BorderRadius.circular(Sizes.cardRadius);

    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CustomerDetailScreen(customerId: balance.customer.id),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.compact, vertical: Gap.compact),
            child: Row(
              children: [
                AvatarCircle(balance.customer.name),
                const SizedBox(width: Gap.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balance.customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMedium(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        balance.lastFiadoAt == null
                            ? 'Sin compras registradas'
                            : 'Última compra: ${Dates.relative(balance.lastFiadoAt!, now: now)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.tight),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      balance.balanceCents,
                      style: AppText.moneyBody(),
                      color: overdue ? c.danger : c.accent,
                    ),
                    if (overdue) ...[
                      const SizedBox(height: 2),
                      Text(
                        'hace ${Dates.daysAgoPhrase(balance.daysOutstanding(now))}',
                        style: AppText.caption(color: c.danger),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibreta extends StatelessWidget {
  const _EmptyLibreta({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      illustration: AppIcon(AppIcons.book, size: 72, color: context.colors.textSecondary),
      title: 'Tu libreta está limpia',
      message: 'Toca + para registrar un fiado',
      action: AppButton(
        label: 'Registrar un fiado',
        icon: AppIcons.plus,
        expand: false,
        onPressed: onAdd,
      ),
    );
  }
}
