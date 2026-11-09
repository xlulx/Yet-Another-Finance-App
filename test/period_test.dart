import 'package:flutter_test/flutter_test.dart';
import 'package:yasba/models/period.dart';

void main() {
  test('periods and moving between them', () {
    final m = Period.month(DateTime(2025, 12, 20));
    expect((m.from, m.to), (DateTime(2025, 12), DateTime(2026)));
    expect(m.shift(1), Period.month(DateTime(2026, 1)));
    expect(m.last, DateTime(2025, 12, 31));

    final y = Period.year(2025);
    expect(y.shift(-1), Period.year(2024));
    expect(y.contains(DateTime(2025, 12, 31, 23)), isTrue);
    expect(y.contains(DateTime(2026)), isFalse);

    final last12 = Period.lastMonths(12, DateTime(2025, 3, 10));
    expect(last12.kind, PeriodKind.last12Months);
    expect((last12.from, last12.to), (DateTime(2024, 4), DateTime(2025, 4)));
    final before = last12.shift(-1);
    expect(before.kind, PeriodKind.custom);
    expect((before.from, before.to), (DateTime(2023, 4), DateTime(2024, 4)));

    // A custom range moves by its own number of days.
    final c = Period.custom(DateTime(2025, 3, 1), DateTime(2025, 3, 10));
    expect(c.to, DateTime(2025, 3, 11));
    final next = c.shift(1);
    expect(
      (next.from, next.last),
      (DateTime(2025, 3, 11), DateTime(2025, 3, 20)),
    );
  });
}
