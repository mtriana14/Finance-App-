import 'package:intl/intl.dart';

/// Money handling for the app.
///
/// Amounts are integer cents everywhere — no `double` appears anywhere in this
/// file, including formatting. Dividing cents by 100 to render them works for
/// the amounts a tienda sees and fails silently somewhere above them; there is
/// no reason to carry that risk when integer arithmetic is just as short.
///
/// Ecuador uses USD. The spec pins the format to `$X.XX` with a decimal point
/// rather than the comma `es_EC` would produce, so the grouping pattern is
/// deliberately built on `en_US`.
abstract final class Money {
  /// Formats the whole-dollar part only. Fed an `int`, `NumberFormat` is exact.
  static final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');

  /// The largest amount [parse] will accept: $999,999,999.99.
  ///
  /// This is not a limit on what a merchant may sell — the spec is explicit
  /// that there is no artificial cap — it is a guard against a typo or a
  /// hostile paste overflowing the arithmetic below.
  static const int maxParsableCents = 99999999999;

  /// `$1,234.56`. Negative amounts render as `-$5.00`.
  static String format(int cents) => '${cents < 0 ? '-' : ''}\$${bare(cents)}';

  /// `1,234.56` — bare, for inputs and CSV cells. Always two decimals.
  static String bare(int cents) {
    final absolute = cents.abs();
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${_grouped.format(absolute ~/ 100)}.$fraction';
  }

  /// `+$5.00` / `-$5.00` — used where direction carries meaning.
  static String signed(int cents) => cents >= 0 ? '+${format(cents)}' : format(cents);

  /// Parses what a merchant might type into cents. Returns null for anything
  /// that isn't a number.
  ///
  /// Both separators are accepted because merchants write either one, which
  /// makes `1,234` genuinely ambiguous. The rule is that a separator followed
  /// by exactly three digits is a thousands separator and anything else is a
  /// decimal point — so `1,234` is one thousand two hundred and thirty four,
  /// and `2,50` is two fifty. Fractions longer than two digits are rounded
  /// half-up on the digits themselves rather than through a `double`.
  static int? parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }

    // Strip currency decoration and both kinds of space.
    text = text.replaceAll(r'$', '').replaceAll(' ', '').replaceAll(' ', '');
    if (!_digitsAndSeparators.hasMatch(text)) return null;
    if (!_hasDigit.hasMatch(text)) return null;

    final lastDot = text.lastIndexOf('.');
    final lastComma = text.lastIndexOf(',');
    final lastSeparator = lastDot > lastComma ? lastDot : lastComma;

    String wholeText;
    String fractionText;
    if (lastSeparator < 0) {
      wholeText = text;
      fractionText = '';
    } else {
      final after = text.substring(lastSeparator + 1);
      if (after.length == 3) {
        // Exactly three trailing digits: a thousands separator.
        wholeText = text;
        fractionText = '';
      } else {
        wholeText = text.substring(0, lastSeparator);
        fractionText = after;
      }
    }

    final wholeDigits = wholeText.replaceAll('.', '').replaceAll(',', '');
    // Any separator left inside the fraction means the text was malformed,
    // e.g. "1.2.3".
    if (fractionText.contains('.') || fractionText.contains(',')) return null;

    final whole = wholeDigits.isEmpty ? 0 : int.tryParse(wholeDigits);
    if (whole == null || whole > maxParsableCents ~/ 100) return null;

    var cents = whole * 100;
    if (fractionText.isNotEmpty) {
      final padded = fractionText.padRight(3, '0');
      final hundredths = int.parse(padded.substring(0, 2));
      final thousandths = int.parse(padded.substring(2, 3));
      // Half-up, carrying into the dollars when the fraction rounds to 100.
      cents += thousandths >= 5 ? hundredths + 1 : hundredths;
    }

    if (cents > maxParsableCents) return null;
    return negative ? -cents : cents;
  }

  /// `12%` — whole-percent, for trend chips.
  static String percent(double fraction) => '${(fraction * 100).round()}%';

  static final RegExp _digitsAndSeparators = RegExp(r'^[0-9.,]+$');
  static final RegExp _hasDigit = RegExp(r'[0-9]');
}
