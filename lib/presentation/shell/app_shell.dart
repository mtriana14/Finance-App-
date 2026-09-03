import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_icon.dart';
import '../historial/historial_screen.dart';
import '../home/home_screen.dart';
import '../libreta/libreta_screen.dart';
import '../perfil/perfil_screen.dart';

/// Which tab of the shell is showing, and any filter a jump carried with it.
final shellTabProvider = StateProvider<int>((ref) => 0);
final historialTodayOnlyProvider = StateProvider<bool>((ref) => false);

/// The persistent bottom-nav shell.
///
/// v1 ships four tabs, not the spec's five: "Crédito" (screens 09-11) is
/// explicitly out of scope until there is a backend to underwrite a loan, and a
/// tab that leads nowhere is worse than no tab. The nav is built so the fifth
/// slot drops in without rework.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = <_TabSpec>[
    _TabSpec('Inicio', HomeScreen()),
    _TabSpec('Libreta', LibretaScreen()),
    _TabSpec('Historial', HistorialScreen()),
    _TabSpec('Perfil', PerfilScreen()),
  ];

  static void goToInicio(BuildContext context) => _jump(context, 0);

  static void goToLibreta(BuildContext context) => _jump(context, 1);

  static void goToHistorial(BuildContext context, {bool todayOnly = false}) {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(historialTodayOnlyProvider.notifier).state = todayOnly;
    _jump(context, 2);
  }

  static void _jump(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ProviderScope.containerOf(context, listen: false)
        .read(shellTabProvider.notifier)
        .state = index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);

    return Scaffold(
      // IndexedStack keeps each tab's scroll position and state alive, so
      // switching tabs never re-runs a query or loses the merchant's place.
      body: IndexedStack(
        index: index,
        children: [for (final tab in _tabs) tab.screen],
      ),
      bottomNavigationBar: _BottomNav(
        index: index,
        onTap: (i) => ref.read(shellTabProvider.notifier).state = i,
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.screen);
  final String label;
  final Widget screen;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static final _icons = [AppIcons.home, AppIcons.book, AppIcons.clock, AppIcons.person];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Below 360dp the labels are hidden and only the active tab keeps its
    // caption, so four (later five) targets still fit without crowding.
    final narrow = MediaQuery.sizeOf(context).width < Sizes.narrowScreen;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.navBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < AppShell._tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _icons[i],
                    label: AppShell._tabs[i].label,
                    active: i == index,
                    showLabel: !narrow || i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.showLabel,
    required this.onTap,
  });

  final AppIconData icon;
  final String label;
  final bool active;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.primary : c.textSecondary;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 22, color: color, strokeWidth: active ? 1.9 : 1.7),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
