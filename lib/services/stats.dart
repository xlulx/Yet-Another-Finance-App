import '../models/category.dart';
import '../models/debt.dart';
import '../models/record.dart';
import '../models/transfer.dart';

class CategoryTotal {
  CategoryTotal(this.category, this.total, this.count);
  final Category category;
  final int total;
  final int count;
}

/// Sums records of the given type per category (largest first).
List<CategoryTotal> totalsByCategory(
  Iterable<Record> records,
  Map<int, Category> categories,
  CategoryType type,
) {
  final totals = <int, int>{};
  final counts = <int, int>{};
  for (final r in records) {
    final c = categories[r.categoryId];
    if (c == null || c.type != type) continue;
    totals[r.categoryId] = (totals[r.categoryId] ?? 0) + r.amount;
    counts[r.categoryId] = (counts[r.categoryId] ?? 0) + 1;
  }
  return [
    for (final e in totals.entries)
      CategoryTotal(categories[e.key]!, e.value, counts[e.key]!),
  ]..sort((a, b) => b.total.compareTo(a.total));
}

/// Transfers seen from [walletId], summed per other wallet: transfers out
/// for [CategoryType.expense], transfers in for [CategoryType.income].
/// Largest first.
List<(int otherWalletId, int total, int count)> transferTotals(
  Iterable<Transfer> transfers,
  int walletId,
  CategoryType type,
) {
  final totals = <int, (int, int)>{};
  for (final t in transfers) {
    final int other;
    if (type == CategoryType.expense && t.fromWalletId == walletId) {
      other = t.toWalletId;
    } else if (type == CategoryType.income && t.toWalletId == walletId) {
      other = t.fromWalletId;
    } else {
      continue;
    }
    final (sum, n) = totals[other] ?? (0, 0);
    totals[other] = (sum + t.amount, n + 1);
  }
  return [
    for (final MapEntry(key: id, value: (sum, n)) in totals.entries)
      (id, sum, n),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Debts closed with money still owed, summed per person: money lent that
/// will not come back for [CategoryType.expense], money borrowed that will
/// not be paid for [CategoryType.income]. Other debt movements are not
/// income or expense and are skipped. Largest first.
List<(String person, int total, int count)> debtTotals(
  Iterable<DebtEvent> events,
  CategoryType type,
) {
  final totals = <String, (String, int, int)>{};
  for (final e in events) {
    if (!e.counts) continue;
    final effect = e.effect;
    if ((type == CategoryType.income) != (effect > 0)) continue;
    final key = e.debt.person.toLowerCase();
    final (name, sum, n) = totals[key] ?? (e.debt.person, 0, 0);
    totals[key] = (name, sum + effect.abs(), n + 1);
  }
  return totals.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Splits records into buckets; [bucketOf] maps a record date to a bucket
/// index. Returns `(income, expense)` pairs. With [walletId], [transfers]
/// into that wallet count as income and out of it as expense. Debts closed
/// with money still owed in [debtEvents] count as expense (lent) or income
/// (borrowed).
List<(int income, int expense)> bucketTotals(
  Iterable<Record> records,
  Map<int, Category> categories,
  int bucketCount,
  int Function(DateTime) bucketOf, {
  Iterable<Transfer> transfers = const [],
  int? walletId,
  Iterable<DebtEvent> debtEvents = const [],
}) {
  final income = List.filled(bucketCount, 0);
  final expense = List.filled(bucketCount, 0);
  for (final r in records) {
    final i = bucketOf(r.date);
    if (i < 0 || i >= bucketCount) continue;
    if (categories[r.categoryId]?.type == CategoryType.income) {
      income[i] += r.amount;
    } else {
      expense[i] += r.amount;
    }
  }
  if (walletId != null) {
    for (final t in transfers) {
      final i = bucketOf(t.date);
      if (i < 0 || i >= bucketCount) continue;
      if (t.toWalletId == walletId) income[i] += t.amount;
      if (t.fromWalletId == walletId) expense[i] += t.amount;
    }
  }
  for (final e in debtEvents) {
    if (!e.counts) continue;
    final i = bucketOf(e.date);
    if (i < 0 || i >= bucketCount) continue;
    if (e.effect > 0) {
      income[i] += e.effect;
    } else {
      expense[i] -= e.effect;
    }
  }
  return [for (var i = 0; i < bucketCount; i++) (income[i], expense[i])];
}

/// How long one bar of a trend chart is.
enum BucketUnit { day, week, month }

/// A period of statistics, [from] up to [to] (exclusive), split into chart
/// buckets: days up to a month, weeks up to about four months, then months.
class StatsRange {
  StatsRange(DateTime from, DateTime to)
    : from = DateTime(from.year, from.month, from.day),
      to = DateTime(to.year, to.month, to.day);

  final DateTime from;
  final DateTime to;

  /// Days since [from]; counted on calendar dates, so daylight saving time
  /// changes do not matter.
  int _dayIndex(DateTime d) => DateTime.utc(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  int get _months => (to.year - from.year) * 12 + to.month - from.month;

  int get days => _dayIndex(to);

  BucketUnit get unit => days <= 31
      ? BucketUnit.day
      : days <= 124
      ? BucketUnit.week
      : BucketUnit.month;

  int get bucketCount => switch (unit) {
    BucketUnit.day => days,
    BucketUnit.week => (days + 6) ~/ 7,
    // A partial last month still gets a bar.
    BucketUnit.month => _months + (to.day > 1 ? 1 : 0),
  };

  /// The bucket a date falls in; outside the range, an index outside
  /// 0 until [bucketCount].
  int bucketOf(DateTime d) => switch (unit) {
    BucketUnit.day => _dayIndex(d),
    BucketUnit.week => _dayIndex(d) < 0 ? -1 : _dayIndex(d) ~/ 7,
    BucketUnit.month => (d.year - from.year) * 12 + d.month - from.month,
  };

  /// First day of bucket [i].
  DateTime bucketStart(int i) => switch (unit) {
    BucketUnit.day => DateTime(from.year, from.month, from.day + i),
    BucketUnit.week => DateTime(from.year, from.month, from.day + 7 * i),
    BucketUnit.month => DateTime(from.year, from.month + i),
  };
}
