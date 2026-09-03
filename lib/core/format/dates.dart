import 'package:intl/intl.dart';

/// Spanish date formatting, plus the "business day" helpers the ledger uses.
abstract final class Dates {
  static const _locale = 'es';

  static final _weekdayLong = DateFormat('EEEE', _locale);
  static final _dayMonthLong = DateFormat("d 'de' MMMM", _locale);
  static final _dayMonthShort = DateFormat('d MMM', _locale);
  static final _time = DateFormat('HH:mm', _locale);
  static final _iso = DateFormat('yyyy-MM-dd', _locale);

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// `Martes, 2 de septiembre`
  static String greetingDate(DateTime d) =>
      '${_cap(_weekdayLong.format(d))}, ${_dayMonthLong.format(d)}';

  /// `Hoy, 2 de septiembre` · `Ayer, 1 de septiembre` · `31 de agosto`
  static String dayHeader(DateTime d, {DateTime? now}) {
    final today = dayStart(now ?? DateTime.now());
    final day = dayStart(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy, ${_dayMonthLong.format(d)}';
    if (diff == 1) return 'Ayer, ${_dayMonthLong.format(d)}';
    return _cap(_dayMonthLong.format(d));
  }

  /// `2 sept` — compact, for transaction rows.
  static String shortDay(DateTime d) => _cap(_dayMonthShort.format(d).replaceAll('.', ''));

  static String time(DateTime d) => _time.format(d);

  static String iso(DateTime d) => _iso.format(d);

  /// Spanish single-letter weekday initials for the 7-day chart: L M M J V S D.
  static String weekdayInitial(DateTime d) =>
      const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][d.weekday - 1];

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The `yyyymmdd` integer the ledger groups on. Sortable and comparable
  /// without any timezone arithmetic.
  static int businessDay(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static DateTime fromBusinessDay(int key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  /// "hace 2 días" — relative age, used for "última compra" and overdue fiados.
  static String relative(DateTime d, {DateTime? now}) {
    final today = dayStart(now ?? DateTime.now());
    final days = today.difference(dayStart(d)).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    if (days < 30) return 'hace $days días';
    final months = days ~/ 30;
    if (months == 1) return 'hace 1 mes';
    if (months < 12) return 'hace $months meses';
    final years = days ~/ 365;
    return years == 1 ? 'hace 1 año' : 'hace $years años';
  }

  static String daysAgoPhrase(int days) => days == 1 ? '1 día' : '$days días';
}
