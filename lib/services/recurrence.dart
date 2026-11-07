import '../models/recurring_rule.dart';

/// [base] tarihine [n] * [rule.interval] birim ekler.
///
/// Ay/yıl eklerken gün, hedef ayın uzunluğuna kırpılır (31 Ocak + 1 ay =
/// 28/29 Şubat). Hesap her zaman başlangıç tarihinden yapıldığı için gün
/// kayması birikmez (31 Ocak -> 28 Şubat -> 31 Mart).
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

/// Kural için [now] anına kadar (dahil) henüz üretilmemiş tarihleri döndürür.
///
/// [RecurringRule.lastGenerated] boşsa başlangıç tarihi de dahil edilir.
/// Sonsuz döngüye karşı [maxCount] sınırı vardır.
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

/// Kuralın bir sonraki (henüz üretilmemiş) tarihini döndürür; bitmişse null.
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
