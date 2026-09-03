import 'package:intl/intl.dart';

/// Money is stored as integer cents everywhere — no float ever touches a
/// balance — and rendered through this one formatter so every screen agrees.
///
/// Ecuador uses USD. The spec pins the format to `$X.XX` with a decimal point
/// (not the comma that `es_EC` would otherwise produce), so the numeric pattern
/// is deliberately built on `en_US`.
abstract final class Money {
  static final NumberFormat _plain = NumberFormat('#,##0.00', 'en_US');

  /// `$1,234.56`. Negative amounts render as `-$5.00`.
  static String format(int cents) {
    final sign = cents < 0 ? '-' : '';
    return '$sign\$${_plain.format(cents.abs() / 100)}';
  }

  /// `+$5.00` / `-$5.00` — used where direction carries meaning.
  static String signed(int cents) => cents >= 0 ? '+${format(cents)}' : format(cents);

  /// Bare `1,234.56`, for inputs and CSV cells.
  static String bare(int cents) => _plain.format(cents / 100);

  /// Parses free text ("2,50" · "2.5" · "$2.50") into cents. Both separators
  /// are accepted on input because merchants type either one.
  static int? parse(String raw) {
    var s = raw.trim().replaceAll(r'$', '').replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      // Whichever separator comes last is the decimal one.
      s = s.lastIndexOf(',') > s.lastIndexOf('.')
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else {
      s = s.replaceAll(',', '.');
    }
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return (value * 100).round();
  }

  /// `12%` — whole-percent, for trend chips and repayment rates.
  static String percent(double fraction) => '${(fraction * 100).round()}%';
}
