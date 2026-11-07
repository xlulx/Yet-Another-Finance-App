import '../models/category.dart';
import '../models/record.dart';

class CategoryTotal {
  CategoryTotal(this.category, this.total, this.count);
  final Category category;
  final int total;
  final int count;
}

/// Verilen türdeki kayıtları kategoriye göre toplar (büyükten küçüğe).
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

/// Kayıtları kovalara böler: [bucketOf] kayıt tarihini kova index'ine çevirir.
/// Dönen liste `(gelir, gider)` çiftleridir.
List<(int income, int expense)> bucketTotals(
  Iterable<Record> records,
  Map<int, Category> categories,
  int bucketCount,
  int Function(DateTime) bucketOf,
) {
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
  return [for (var i = 0; i < bucketCount; i++) (income[i], expense[i])];
}
