import 'package:flutter_test/flutter_test.dart';
import 'package:yafa/models/recurring_rule.dart';
import 'package:yafa/services/recurrence.dart';

RecurringRule rule(
  DateTime start, {
  int interval = 1,
  RecurrenceUnit unit = RecurrenceUnit.month,
  DateTime? end,
  DateTime? last,
}) => RecurringRule(
  title: 'x',
  amount: 100,
  categoryId: 1,
  startDate: start,
  interval: interval,
  unit: unit,
  endDate: end,
  lastGenerated: last,
);

void main() {
  test('month end is clamped without drift', () {
    final r = rule(DateTime(2025, 1, 31));
    expect(nthOccurrence(r, 1), DateTime(2025, 2, 28));
    expect(nthOccurrence(r, 2), DateTime(2025, 3, 31));
    expect(nthOccurrence(r, 13), DateTime(2026, 2, 28));
    expect(
      nthOccurrence(rule(DateTime(2024, 1, 31)), 1),
      DateTime(2024, 2, 29),
    );
  });

  test('yearly rule on Feb 29 of a leap year', () {
    final r = rule(DateTime(2024, 2, 29), unit: RecurrenceUnit.year);
    expect(nthOccurrence(r, 1), DateTime(2025, 2, 28));
    expect(nthOccurrence(r, 4), DateTime(2028, 2, 29));
  });

  test('pending dates include start and now', () {
    final r = rule(DateTime(2025, 1, 10));
    expect(pendingOccurrences(r, DateTime(2025, 3, 10)), [
      DateTime(2025, 1, 10),
      DateTime(2025, 2, 10),
      DateTime(2025, 3, 10),
    ]);
  });

  test('only dates after lastGenerated are pending', () {
    final r = rule(DateTime(2025, 1, 10), last: DateTime(2025, 2, 10));
    expect(pendingOccurrences(r, DateTime(2025, 4, 1)), [
      DateTime(2025, 3, 10),
    ]);
    expect(nextOccurrence(r), DateTime(2025, 3, 10));
  });

  test('end date is respected', () {
    final r = rule(
      DateTime(2025, 1, 1),
      unit: RecurrenceUnit.week,
      interval: 2,
      end: DateTime(2025, 1, 31),
    );
    expect(pendingOccurrences(r, DateTime(2026)), [
      DateTime(2025, 1, 1),
      DateTime(2025, 1, 15),
      DateTime(2025, 1, 29),
    ]);
    expect(
      nextOccurrence(r.copyWith(lastGenerated: DateTime(2025, 1, 29))),
      isNull,
    );
  });

  test('rule starting in the future generates nothing', () {
    final r = rule(DateTime(2030), unit: RecurrenceUnit.day);
    expect(pendingOccurrences(r, DateTime(2025)), isEmpty);
  });
}
