/// A fiado customer. Name is the only thing ever required — the spec is
/// explicit that asking for more at entry time kills the flow.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// A customer plus the derived state the Libreta list needs.
class CustomerBalance {
  const CustomerBalance({
    required this.customer,
    required this.balanceCents,
    this.lastFiadoAt,
    this.oldestOutstandingAt,
  });

  final Customer customer;

  /// Fiados issued minus payments received, never below zero.
  final int balanceCents;

  /// "Última compra" — when this customer last took credit.
  final DateTime? lastFiadoAt;

  /// Age of the oldest still-unpaid fiado, resolved oldest-first. Null when the
  /// customer is settled up. This is what turns the amount red past 30 days.
  final DateTime? oldestOutstandingAt;

  bool get hasDebt => balanceCents > 0;

  int daysOutstanding(DateTime now) {
    final since = oldestOutstandingAt;
    if (since == null) return 0;
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(since.year, since.month, since.day))
        .inDays;
  }

  bool isOverdue(DateTime now) => hasDebt && daysOutstanding(now) > 30;
}
