import '../models/customer.dart';
import '../models/daily_totals.dart';
import '../models/ledger_entry.dart';
import '../models/ledger_kind.dart';

/// Every number the app shows is derived here.
///
/// These are pure functions over plain models on purpose: the spec's "Business
/// Logic Integrity" checklist is a list of claims about arithmetic, and
/// arithmetic that lives in SQL strings or in widgets can't be tested. The
/// repositories query rows; this file decides what they mean.
abstract final class LedgerMath {
  /// Ventas del día = QR + tarjeta + efectivo + cobros de fiado.
  ///
  /// Two exclusions are structural rather than subtracted afterwards:
  /// fiados *issued* are money lent (tracked separately in
  /// [DailyTotals.fiadoIssuedCents]), and entries replaced by an end-of-day
  /// close no longer exist for totalling purposes.
  static DailyTotals totals(Iterable<LedgerEntry> entries) {
    var qr = 0, card = 0, cash = 0, collected = 0, issued = 0, count = 0;
    for (final e in entries) {
      if (e.supersededByCloseout) continue;
      count++;
      switch (e.kind) {
        case LedgerKind.qrSale:
          qr += e.amountCents;
        case LedgerKind.cardSale:
          card += e.amountCents;
        case LedgerKind.cashSale:
          cash += e.amountCents;
        case LedgerKind.fiadoPayment:
          collected += e.amountCents;
        case LedgerKind.fiadoIssued:
          issued += e.amountCents;
      }
    }
    return DailyTotals(
      qrCents: qr,
      cardCents: card,
      cashCents: cash,
      fiadoCollectedCents: collected,
      fiadoIssuedCents: issued,
      entryCount: count,
    );
  }

  /// Groups entries into calendar days, newest day first, each day's entries
  /// newest first. This is the whole of Historial.
  static List<({DateTime day, List<LedgerEntry> entries, DailyTotals totals})> groupByDay(
    Iterable<LedgerEntry> entries,
  ) {
    final buckets = <int, List<LedgerEntry>>{};
    for (final e in entries) {
      final key = e.occurredAt.year * 10000 + e.occurredAt.month * 100 + e.occurredAt.day;
      (buckets[key] ??= []).add(e);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        (
          day: DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100),
          entries: buckets[k]!..sort(_newestFirst),
          totals: totals(buckets[k]!),
        ),
    ];
  }

  static int _newestFirst(LedgerEntry a, LedgerEntry b) {
    final byTime = b.occurredAt.compareTo(a.occurredAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  // -------------------------------------------------------------------------
  // Fiado balances
  // -------------------------------------------------------------------------

  /// Resolves each customer's outstanding balance and, critically, the age of
  /// their oldest *unpaid* fiado.
  ///
  /// Payments are applied oldest-fiado-first (FIFO). That matters: a customer
  /// who owes $45 across three fiados isn't "35 days overdue" because their
  /// first-ever fiado was 35 days ago — they're overdue only if the money still
  /// outstanding is old. Aging the remaining balance rather than the account is
  /// what makes the red state honest.
  static List<CustomerBalance> balances(
    Iterable<Customer> customers,
    Iterable<LedgerEntry> fiadoEntries,
  ) {
    final byCustomer = <int, List<LedgerEntry>>{};
    for (final e in fiadoEntries) {
      final id = e.customerId;
      if (id == null || !e.kind.isFiado || e.supersededByCloseout) continue;
      (byCustomer[id] ??= []).add(e);
    }
    return [
      for (final c in customers) _balanceFor(c, byCustomer[c.id] ?? const []),
    ];
  }

  static CustomerBalance _balanceFor(Customer customer, List<LedgerEntry> entries) {
    final ordered = [...entries]..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    // Unpaid fiado lots, oldest at the front.
    final lots = <({DateTime at, int remaining})>[];
    DateTime? lastFiadoAt;

    for (final e in ordered) {
      if (e.kind == LedgerKind.fiadoIssued) {
        lots.add((at: e.occurredAt, remaining: e.amountCents));
        lastFiadoAt = e.occurredAt;
      } else if (e.kind == LedgerKind.fiadoPayment) {
        var left = e.amountCents;
        while (left > 0 && lots.isNotEmpty) {
          final front = lots.first;
          if (front.remaining > left) {
            lots[0] = (at: front.at, remaining: front.remaining - left);
            left = 0;
          } else {
            left -= front.remaining;
            lots.removeAt(0);
          }
        }
        // Any excess is dropped: the UI caps a payment at the amount owed, so
        // an overpayment can only mean a corrected entry, never a credit.
      }
    }

    final balance = lots.fold<int>(0, (sum, lot) => sum + lot.remaining);
    return CustomerBalance(
      customer: customer,
      balanceCents: balance,
      lastFiadoAt: lastFiadoAt,
      oldestOutstandingAt: lots.isEmpty ? null : lots.first.at,
    );
  }

  /// "Te deben" — the sum of every outstanding balance, all customers, all time.
  static int outstandingTotal(Iterable<CustomerBalance> balances) =>
      balances.fold(0, (sum, b) => sum + b.balanceCents);

  /// Running balance beside each row of a customer's statement.
  ///
  /// The balance shown is the one *after* that entry, and the list comes back
  /// newest-first for display.
  static List<({LedgerEntry entry, int balanceCents})> statement(
    Iterable<LedgerEntry> entries,
  ) {
    final ordered = [...entries]..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final rows = <({LedgerEntry entry, int balanceCents})>[];
    var running = 0;
    for (final e in ordered) {
      running += e.kind == LedgerKind.fiadoIssued ? e.amountCents : -e.amountCents;
      if (running < 0) running = 0;
      rows.add((entry: e, balanceCents: running));
    }
    return rows.reversed.toList();
  }

  // -------------------------------------------------------------------------
  // Dashboard derivations
  // -------------------------------------------------------------------------

  /// Today-so-far against the *same point* yesterday.
  ///
  /// Comparing a half-finished day to a full one would show every merchant a
  /// red arrow every morning, so yesterday is truncated to the current
  /// time of day. Returns null when there is nothing to compare against, which
  /// the UI renders gray rather than as 0%.
  static double? trend({
    required Iterable<LedgerEntry> today,
    required Iterable<LedgerEntry> yesterday,
    required DateTime now,
  }) {
    final cutoff = now.hour * 3600 + now.minute * 60 + now.second;
    var todayCents = 0;
    for (final e in today) {
      if (e.countsAsIncome) todayCents += e.amountCents;
    }
    var yesterdayCents = 0;
    var sawAny = false;
    for (final e in yesterday) {
      if (!e.countsAsIncome) continue;
      sawAny = true;
      final at = e.occurredAt.hour * 3600 + e.occurredAt.minute * 60 + e.occurredAt.second;
      if (at <= cutoff) yesterdayCents += e.amountCents;
    }
    if (!sawAny || yesterdayCents == 0) return null;
    return (todayCents - yesterdayCents) / yesterdayCents;
  }

  /// The seven bars under the hero number, oldest to newest, ending today.
  static List<DayBar> weekBars({
    required Iterable<LedgerEntry> entries,
    required DateTime now,
    DateTime? firstActivityDay,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final sums = <int, int>{};
    for (final e in entries) {
      if (!e.countsAsIncome) continue;
      final key = e.occurredAt.year * 10000 + e.occurredAt.month * 100 + e.occurredAt.day;
      sums[key] = (sums[key] ?? 0) + e.amountCents;
    }
    final firstDay = firstActivityDay == null
        ? null
        : DateTime(firstActivityDay.year, firstActivityDay.month, firstActivityDay.day);

    return [
      for (var i = 6; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          final key = day.year * 10000 + day.month * 100 + day.day;
          return DayBar(
            day: day,
            totalCents: sums[key] ?? 0,
            // Days before the merchant ever used the app are placeholders, not
            // zero-sales days — claiming otherwise would misreport the trend.
            hasData: firstDay == null ? false : !day.isBefore(firstDay),
          );
        }(),
    ];
  }

  // -------------------------------------------------------------------------
  // Guards
  // -------------------------------------------------------------------------

  /// Detects the double-count the spec singles out: a fiado paid in cash, then
  /// logged a second time as a plain cash sale.
  ///
  /// Amounts are matched loosely because a merchant rounds — within a dollar,
  /// or within 10% on larger amounts.
  static LedgerEntry? matchingRecentFiadoPayment({
    required Iterable<LedgerEntry> recentPayments,
    required int amountCents,
    required DateTime now,
    Duration window = const Duration(minutes: 5),
  }) {
    final tolerance = amountCents ~/ 10 > 100 ? amountCents ~/ 10 : 100;
    for (final e in recentPayments) {
      if (e.kind != LedgerKind.fiadoPayment) continue;
      if (now.difference(e.createdAt).abs() > window) continue;
      if ((e.amountCents - amountCents).abs() <= tolerance) return e;
    }
    return null;
  }

  /// Cash counted in the drawer, less the float that was there this morning.
  /// Never negative — a miscount shouldn't book a negative sale.
  static int closeoutSales({required int drawerCents, required int floatCents}) {
    final v = drawerCents - floatCents;
    return v < 0 ? 0 : v;
  }

  // -------------------------------------------------------------------------
  // Customer name matching
  // -------------------------------------------------------------------------

  /// Accent- and case-insensitive key, so "María" and "maria" collide.
  static String normalizeName(String raw) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final lower = raw.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Existing customers that look like what the merchant just typed, so the app
  /// can ask "¿Es esta persona?" instead of silently creating a duplicate.
  static List<Customer> similarCustomers(String typed, Iterable<Customer> existing) {
    final target = normalizeName(typed);
    if (target.length < 3) return const [];
    final matches = <(int, Customer)>[];
    for (final c in existing) {
      final name = normalizeName(c.name);
      if (name == target) {
        matches.add((0, c));
      } else if (name.startsWith(target) || target.startsWith(name)) {
        matches.add((1, c));
      } else if (name.contains(target) || target.contains(name)) {
        matches.add((2, c));
      } else {
        final d = _editDistance(name, target);
        if (d <= (target.length >= 6 ? 2 : 1)) matches.add((3 + d, c));
      }
    }
    matches.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final m in matches.take(3)) m.$2];
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 3) return 99;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final del = prev[j] + 1;
        final ins = cur[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Deterministic avatar tint: the same name always yields the same color, so
  /// a customer's circle never changes between sessions or devices.
  static int avatarPaletteIndex(String name, int paletteSize) {
    final key = normalizeName(name);
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % paletteSize;
  }
}
