import 'package:flutter/material.dart' show ThemeMode;

import '../db/database.dart';

/// Typed access to the handful of settings v1 has. Stored in the same database
/// as everything else so "exportar mis datos" and "eliminar mi cuenta" have one
/// place to look.
class AppSettings {
  const AppSettings({
    this.merchantName = '',
    this.businessName = '',
    this.cashFloatCents = 0,
    this.presetAmountsCents = defaultPresets,
    this.themeMode = ThemeMode.system,
    this.sortByRecent = false,
  });

  /// The spec's default quick-amount grid, in cents.
  static const List<int> defaultPresets = [50, 100, 200, 500, 1000, 2000, 5000, 10000];

  final String merchantName;
  final String businessName;

  /// Cash in the drawer at open, subtracted by the end-of-day close.
  final int cashFloatCents;

  /// Eight customisable presets; the ninth cell of the grid is always "Otro".
  final List<int> presetAmountsCents;

  final ThemeMode themeMode;

  /// Libreta sort: highest debt first (default) or most recent.
  final bool sortByRecent;

  String get greetingName => merchantName.trim().isEmpty ? 'comerciante' : merchantName.trim();
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _merchantName = 'merchant_name';
  static const _businessName = 'business_name';
  static const _cashFloat = 'cash_float_cents';
  static const _presets = 'preset_amounts';
  static const _theme = 'theme_mode';
  static const _sortRecent = 'libreta_sort_recent';

  Stream<AppSettings> watch() =>
      _db.select(_db.settings).watch().map(_fromRows);

  Future<AppSettings> read() async => _fromRows(await _db.select(_db.settings).get());

  AppSettings _fromRows(List<SettingRow> rows) {
    final map = {for (final r in rows) r.key: r.value};
    return AppSettings(
      merchantName: map[_merchantName] ?? '',
      businessName: map[_businessName] ?? '',
      cashFloatCents: int.tryParse(map[_cashFloat] ?? '') ?? 0,
      presetAmountsCents: _parsePresets(map[_presets]),
      themeMode: switch (map[_theme]) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      sortByRecent: map[_sortRecent] == '1',
    );
  }

  static List<int> _parsePresets(String? raw) {
    if (raw == null || raw.isEmpty) return AppSettings.defaultPresets;
    final parsed = [
      for (final part in raw.split(',')) int.tryParse(part.trim()),
    ].whereType<int>().where((v) => v > 0).toList();
    return parsed.length == AppSettings.defaultPresets.length
        ? parsed
        : AppSettings.defaultPresets;
  }

  Future<void> _put(String key, String value) => _db.into(_db.settings).insertOnConflictUpdate(
        SettingRow(key: key, value: value),
      );

  Future<void> setMerchantName(String v) => _put(_merchantName, v.trim());
  Future<void> setBusinessName(String v) => _put(_businessName, v.trim());
  Future<void> setCashFloat(int cents) => _put(_cashFloat, '$cents');
  Future<void> setPresets(List<int> cents) => _put(_presets, cents.join(','));
  Future<void> setSortByRecent(bool v) => _put(_sortRecent, v ? '1' : '0');

  Future<void> setThemeMode(ThemeMode mode) => _put(
        _theme,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );

  Future<void> deleteAll() => _db.delete(_db.settings).go();
}
