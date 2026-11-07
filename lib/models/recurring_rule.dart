/// Tekrar birimi. Index veritabanında saklanır; sadece sona ekleyin.
enum RecurrenceUnit { day, week, month, year }

/// Belirli aralıklarla otomatik kayıt üreten kural (kira, maaş, abonelik...).
class RecurringRule {
  final int? id;
  final String title;
  final int amount;
  final int categoryId;
  final String? note;

  /// İlk kaydın tarihi.
  final DateTime startDate;

  /// Her [interval] [unit]'te bir tekrarlanır (ör. 3 ay).
  final int interval;
  final RecurrenceUnit unit;

  /// Doluysa bu tarihten sonra kayıt üretilmez.
  final DateTime? endDate;

  /// Şimdiye kadar üretilen son kaydın tarihi.
  final DateTime? lastGenerated;

  const RecurringRule({
    this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.startDate,
    this.interval = 1,
    this.unit = RecurrenceUnit.month,
    this.endDate,
    this.lastGenerated,
  });

  RecurringRule copyWith({
    int? id,
    String? title,
    int? amount,
    int? categoryId,
    String? note,
    DateTime? startDate,
    int? interval,
    RecurrenceUnit? unit,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? lastGenerated,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      startDate: startDate ?? this.startDate,
      interval: interval ?? this.interval,
      unit: unit ?? this.unit,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      lastGenerated: lastGenerated ?? this.lastGenerated,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category_id': categoryId,
    'note': note,
    'start_date': startDate.millisecondsSinceEpoch,
    'interval': interval,
    'unit': unit.index,
    'end_date': endDate?.millisecondsSinceEpoch,
    'last_generated': lastGenerated?.millisecondsSinceEpoch,
  };

  factory RecurringRule.fromRow(Map<String, Object?> row) {
    DateTime? ms(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return RecurringRule(
      id: row['id'] as int?,
      title: row['title'] as String? ?? '',
      amount: row['amount'] as int,
      categoryId: row['category_id'] as int,
      note: row['note'] as String?,
      startDate: ms(row['start_date'])!,
      interval: row['interval'] as int? ?? 1,
      unit: RecurrenceUnit.values[row['unit'] as int? ?? 2],
      endDate: ms(row['end_date']),
      lastGenerated: ms(row['last_generated']),
    );
  }
}
