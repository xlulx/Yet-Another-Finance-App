import '../models/category.dart';
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

/// Splits records into buckets; [bucketOf] maps a record date to a bucket
/// index. Returns `(income, expense)` pairs. With [walletId], [transfers]
/// into that wallet count as income and out of it as expense.
List<(int income, int expense)> bucketTotals(
  Iterable<Record> records,
  Map<int, Category> categories,
  int bucketCount,
  int Function(DateTime) bucketOf, {
  Iterable<Transfer> transfers = const [],
  int? walletId,
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
  return [for (var i = 0; i < bucketCount; i++) (income[i], expense[i])];
}
