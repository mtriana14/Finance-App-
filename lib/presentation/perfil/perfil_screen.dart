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
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../historial/export.dart';

/// Screen 12 — profile and settings.
///
/// v1 has no account, so this is the handful of settings that actually exist:
/// the two names shown around the app, the cash float the day-close subtracts,
/// the quick-amount grid, appearance, and the data controls.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final since = ref.watch(firstActivityDayProvider).value;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.standard, 0, Gap.standard, Gap.major),
        children: [
          _ProfileHeader(settings: settings, since: since),
          const SizedBox(height: Gap.section),
          _SectionLabel('Tu negocio'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: AppIcons.person,
                title: 'Tu nombre',
                value: settings.merchantName.isEmpty ? 'Sin definir' : settings.merchantName,
                onTap: () => _editText(
                  context,
                  title: 'Tu nombre',
                  initial: settings.merchantName,
                  maxLength: 40,
                  onSave: ref.read(settingsRepositoryProvider).setMerchantName,
                ),
              ),
              _SettingsTile(
                icon: AppIcons.book,
                title: 'Nombre del negocio',
                value: settings.businessName.isEmpty ? 'Sin definir' : settings.businessName,
                onTap: () => _editText(
                  context,
                  title: 'Nombre del negocio',
                  initial: settings.businessName,
                  maxLength: 40,
                  onSave: ref.read(settingsRepositoryProvider).setBusinessName,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.section),
          _SectionLabel('Ventas'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: AppIcons.wallet,
                title: 'Fondo de caja',
                subtitle: 'Se resta en el cierre del día',
                value: Money.format(settings.cashFloatCents),
                onTap: () async {
                  final entered = await showAmountKeypad(
                    context,
                    title: 'Fondo de caja',
                    initialCents: settings.cashFloatCents,
                    confirmLabel: 'Guardar',
                  );
                  if (entered != null) {
                    await ref.read(settingsRepositoryProvider).setCashFloat(entered);
                  }
                },
              ),
              _SettingsTile(
                icon: AppIcons.cash,
                title: 'Montos rápidos',
                subtitle: 'Los botones de la pantalla de venta',
                value: '${settings.presetAmountsCents.length} montos',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _PresetsSheet(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.section),
          _SectionLabel('Apariencia'),
          _SettingsGroup(
            children: [
              _ThemeTile(mode: settings.themeMode),
              _SettingsTile(
                icon: AppIcons.info,
                title: 'Idioma',
                value: 'Español',
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: Gap.section),
          _SectionLabel('Datos y privacidad'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: AppIcons.download,
                title: 'Exportar mis datos',
                subtitle: 'Todo tu historial en un archivo CSV',
                onTap: () => _exportAll(context, ref),
              ),
              _SettingsTile(
                icon: AppIcons.trash,
                title: 'Borrar todos mis datos',
                subtitle: 'Ventas, fiados e historial',
                destructive: true,
                onTap: () => _deleteEverything(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Gap.section),
          _DataNotice(),
          const SizedBox(height: Gap.section),
          Center(
            child: Column(
              children: [
                Text('Libreta 0.1.0', style: AppText.caption(color: c.textDisabled)),
                const SizedBox(height: Gap.micro),
                Text('Hecho en Ecuador', style: AppText.caption(color: c.textDisabled)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final entries = await ref.read(ledgerRepositoryProvider).exportAll();
    if (!context.mounted) return;
    if (entries.isEmpty) {
      showSnack(context, 'Todavía no hay datos para exportar');
      return;
    }
    try {
      await LedgerExport.shareCsv(entries, name: 'mis-datos');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'No se pudo crear el archivo', danger: true);
      }
    }
  }

  Future<void> _deleteEverything(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: '¿Borrar todos tus datos?',
      message:
          'Esto borrará todas tus ventas, fiados e historial de este teléfono. '
          'No se puede deshacer.',
      confirmLabel: 'Borrar todo',
      destructive: true,
      icon: AppIcons.alert,
    );
    if (!ok || !context.mounted) return;

    // Entries first, then customers: the cascade would take the entries anyway,
    // but deleting in this order leaves no window where a row points at a
    // customer that is already gone.
    await ref.read(ledgerRepositoryProvider).deleteAll();
    await ref.read(customerRepositoryProvider).deleteAll();
    await ref.read(settingsRepositoryProvider).deleteAll();
    if (context.mounted) showSnack(context, 'Datos borrados');
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required int maxLength,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final c = context.colors;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: Gap.standard,
              right: Gap.standard,
              top: Gap.section,
              bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.standard,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.subheading(color: c.textPrimary)),
                const SizedBox(height: Gap.standard),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: maxLength,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.body(color: c.textPrimary),
                ),
                const SizedBox(height: Gap.tight),
                AppButton(
                  label: 'Guardar',
                  large: true,
                  onPressed: () => Navigator.of(context).pop(controller.text),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (result != null) await onSave(result);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.settings, required this.since});

  final AppSettings settings;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final display = settings.businessName.isNotEmpty
        ? settings.businessName
        : (settings.merchantName.isNotEmpty ? settings.merchantName : 'Mi negocio');

    return AppCard(
      child: Row(
        children: [
          AvatarCircle(display, size: 56),
          const SizedBox(width: Gap.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subheading(color: c.textPrimary),
                ),
                if (settings.merchantName.isNotEmpty && settings.businessName.isNotEmpty)
                  Text(
                    settings.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall(color: c.textSecondary),
                  ),
                const SizedBox(height: 2),
                Text(
                  since == null
                      ? 'Sin registros todavía'
                      : 'Usando Libreta desde ${Dates.shortDay(since!)}',
                  style: AppText.caption(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.tight, left: Gap.micro),
      child: Text(text.toUpperCase(),
          style: AppText.caption(color: context.colors.textSecondary)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(color: c.border, height: 1, indent: Gap.standard + 28),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  final AppIconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = destructive ? c.danger : c.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.standard, vertical: Gap.compact),
        child: SizedBox(
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: tint),
              const SizedBox(width: Gap.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.bodySmallMedium(
                          color: destructive ? c.danger : c.textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: Gap.tight),
                Text(value!, style: AppText.bodySmall(color: c.textSecondary)),
              ],
              if (onTap != null) ...[
                const SizedBox(width: Gap.tight),
                AppIcon(AppIcons.chevronRight, size: 18, color: c.textDisabled),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark mode switches immediately — no restart, per the spec's checkpoint.
class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    const options = [
      (ThemeMode.system, 'Sistema'),
      (ThemeMode.light, 'Claro'),
      (ThemeMode.dark, 'Oscuro'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.standard, vertical: Gap.compact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.moon, size: 20, color: c.textSecondary),
              const SizedBox(width: Gap.compact),
              Text('Modo oscuro', style: AppText.bodySmallMedium(color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: Gap.compact),
          Row(
            children: [
              for (final (value, label) in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: Gap.tight),
                    child: Material(
                      color: value == mode ? c.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(Sizes.cardRadius),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Sizes.cardRadius),
                        onTap: () => ref.read(settingsRepositoryProvider).setThemeMode(value),
                        child: Ink(
                          height: Sizes.tapTarget - 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Sizes.cardRadius),
                            border: Border.all(
                              color: value == mode ? c.primary : c.border,
                              width: value == mode ? 1.4 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: AppText.bodySmall(
                                color: value == mode ? c.primary : c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetsSheet extends ConsumerWidget {
  const _PresetsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final presets = ref.watch(settingsProvider).value?.presetAmountsCents ??
        AppSettings.defaultPresets;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.standard, Gap.section, Gap.standard, Gap.standard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Montos rápidos', style: AppText.subheading(color: c.textPrimary)),
            const SizedBox(height: Gap.micro),
            Text(
              'Toca un monto para cambiarlo por el que más vendes.',
              style: AppText.bodySmall(color: c.textSecondary),
            ),
            const SizedBox(height: Gap.standard),
            PresetGrid(
              presets: presets,
              onAdd: (_) {},
              onOther: () {},
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
            AppButton(
              label: 'Restaurar montos por defecto',
              style: AppButtonStyle.outline,
              onPressed: () =>
                  ref.read(settingsRepositoryProvider).setPresets(AppSettings.defaultPresets),
            ),
            const SizedBox(height: Gap.tight),
            AppButton(
              label: 'Listo',
              large: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// v1 keeps everything on the phone. A merchant trusting a notebook
/// replacement with her receivables deserves to be told that plainly, not to
/// discover it when the phone is lost.
class _DataNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const WarningBanner(
      tone: WarningTone.info,
      message: 'Tus datos se guardan solo en este teléfono. Todavía no hay copia en internet, '
          'así que exporta tu CSV de vez en cuando para no perder tu libreta.',
    );
  }
}
