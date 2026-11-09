import 'package:flutter_test/flutter_test.dart';
import 'package:yasba/services/stats.dart';

void main() {
  test('a month is split into days', () {
    final r = StatsRange(DateTime(2025, 2, 1), DateTime(2025, 3, 1));
    expect(r.unit, BucketUnit.day);
    expect(r.bucketCount, 28);
    expect(r.bucketOf(DateTime(2025, 2, 1, 23, 59)), 0);
    expect(r.bucketOf(DateTime(2025, 2, 28)), 27);
    expect(r.bucketOf(DateTime(2025, 3, 1)), 28); // outside
  });

  test('three months are split into weeks', () {
    final r = StatsRange(DateTime(2025, 9, 1), DateTime(2025, 12, 1));
    expect(r.unit, BucketUnit.week);
    expect(r.days, 91);
    expect(r.bucketCount, 13);
    expect(r.bucketOf(DateTime(2025, 9, 7)), 0);
    expect(r.bucketOf(DateTime(2025, 9, 8)), 1);
    expect(r.bucketOf(DateTime(2025, 11, 30)), 12);
    expect(r.bucketOf(DateTime(2025, 8, 31)), -1);
    expect(r.bucketStart(1), DateTime(2025, 9, 8));
  });

  test('a year, and ranges across years, are split into months', () {
    final year = StatsRange(DateTime(2025), DateTime(2026));
    expect(year.unit, BucketUnit.month);
    expect(year.bucketCount, 12);
    expect(year.bucketOf(DateTime(2025, 12, 31)), 11);

    final last12 = StatsRange(DateTime(2024, 12), DateTime(2025, 12));
    expect(last12.bucketCount, 12);
    expect(last12.bucketOf(DateTime(2025, 1, 15)), 1);
    expect(last12.bucketStart(11), DateTime(2025, 11));

    // A custom range ending mid-month keeps a bar for that month.
    final custom = StatsRange(DateTime(2025, 1, 15), DateTime(2025, 7, 11));
    expect(custom.unit, BucketUnit.month);
    expect(custom.bucketCount, 7);
    expect(custom.bucketOf(DateTime(2025, 7, 10)), 6);
  });

  test('daylight saving time does not shift days', () {
    // Turkey has none; Europe changes clocks on the last Sunday of March.
    final r = StatsRange(DateTime(2025, 3, 1), DateTime(2025, 4, 1));
    expect(r.bucketCount, 31);
    expect(r.bucketOf(DateTime(2025, 3, 31, 0, 30)), 30);
  });
}
