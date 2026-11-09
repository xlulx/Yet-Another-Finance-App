/// What kind of period is shown on the records and statistics pages.
enum PeriodKind { month, year, last3Months, last12Months, custom }

/// The period shown on the records and statistics pages, shared by both:
/// [from] up to [to] (exclusive), whole days.
class Period {
  const Period._(this.kind, this.from, this.to);

  factory Period.month(DateTime d) => Period._(
    PeriodKind.month,
    DateTime(d.year, d.month),
    DateTime(d.year, d.month + 1),
  );

  factory Period.year(int year) =>
      Period._(PeriodKind.year, DateTime(year), DateTime(year + 1));

  /// The last 3 or 12 months, up to and including the month of [now].
  factory Period.lastMonths(int months, DateTime now) => Period._(
    months == 3 ? PeriodKind.last3Months : PeriodKind.last12Months,
    DateTime(now.year, now.month - months + 1),
    DateTime(now.year, now.month + 1),
  );

  /// From [first] to [last], both included.
  factory Period.custom(DateTime first, DateTime last) => Period._(
    PeriodKind.custom,
    DateTime(first.year, first.month, first.day),
    DateTime(last.year, last.month, last.day + 1),
  );

  final PeriodKind kind;
  final DateTime from;
  final DateTime to;

  /// The last day included.
  DateTime get last => DateTime(to.year, to.month, to.day - 1);

  bool contains(DateTime d) => !d.isBefore(from) && d.isBefore(to);

  /// The previous ([delta] < 0) or next period of the same length: a month,
  /// a year, or as many months or days as this one covers.
  Period shift(int delta) {
    switch (kind) {
      case PeriodKind.month:
        return Period.month(DateTime(from.year, from.month + delta));
      case PeriodKind.year:
        return Period.year(from.year + delta);
      case PeriodKind.last3Months:
      case PeriodKind.last12Months:
        // Moved away from now, it is no longer "the last N months".
        final n = kind == PeriodKind.last3Months ? 3 : 12;
        return Period._(
          PeriodKind.custom,
          DateTime(from.year, from.month + n * delta),
          DateTime(to.year, to.month + n * delta),
        );
      case PeriodKind.custom:
        final days = DateTime.utc(
          to.year,
          to.month,
          to.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
        return Period._(
          PeriodKind.custom,
          DateTime(from.year, from.month, from.day + days * delta),
          DateTime(to.year, to.month, to.day + days * delta),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);
}
