import '../models/recurring_rule.dart';

/// Returns the [n]th occurrence of [rule] (n = 0 is the start date).
///
/// When adding months/years the day is clamped to the target month's length
/// (Jan 31 + 1 month = Feb 28/29). Every occurrence is computed from the
/// start date, so clamping never accumulates (Jan 31 -> Feb 28 -> Mar 31).
DateTime nthOccurrence(RecurringRule rule, int n) {
  final s = rule.startDate;
  final step = rule.interval * n;
  switch (rule.unit) {
    case RecurrenceUnit.day:
      return DateTime(s.year, s.month, s.day + step, s.hour, s.minute);
    case RecurrenceUnit.week:
      return DateTime(s.year, s.month, s.day + 7 * step, s.hour, s.minute);
    case RecurrenceUnit.month:
      return _addMonths(s, step);
    case RecurrenceUnit.year:
      return _addMonths(s, 12 * step);
  }
}

DateTime _addMonths(DateTime d, int months) {
  final totalMonths = d.year * 12 + (d.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(year, month, day, d.hour, d.minute);
}

/// Returns the not yet generated occurrences of [rule] up to [now] (inclusive).
///
/// If [RecurringRule.lastGenerated] is null the start date is included.
/// [maxCount] guards against runaway loops.
List<DateTime> pendingOccurrences(
  RecurringRule rule,
  DateTime now, {
  int maxCount = 5000,
}) {
  if (rule.interval < 1) return const [];
  final result = <DateTime>[];
  final limit = (rule.endDate != null && rule.endDate!.isBefore(now))
      ? rule.endDate!
      : now;
  for (var n = 0; n < maxCount; n++) {
    final date = nthOccurrence(rule, n);
    if (date.isAfter(limit)) break;
    if (rule.lastGenerated == null || date.isAfter(rule.lastGenerated!)) {
      result.add(date);
    }
  }
  return result;
}

/// Returns the next not yet generated occurrence, or null if the rule ended.
DateTime? nextOccurrence(RecurringRule rule, {int maxCount = 5000}) {
  for (var n = 0; n < maxCount; n++) {
    final date = nthOccurrence(rule, n);
    if (rule.endDate != null && date.isAfter(rule.endDate!)) return null;
    if (rule.lastGenerated == null || date.isAfter(rule.lastGenerated!)) {
      return date;
    }
  }
  return null;
}
