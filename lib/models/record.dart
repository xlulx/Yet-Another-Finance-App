/// A single income/expense record.
///
/// Amounts are stored as integers in minor units (cents) to avoid rounding
/// errors. [amount] is always positive; the category type gives the sign.
class Record {
  final int? id;
  final String title;
  final int amount;
  final DateTime date;
  final int categoryId;
  final String? note;

  /// Id of the recurring rule that generated this record, if any.
  final int? recurringId;

  const Record({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.note,
    this.recurringId,
  });

  Record copyWith({
    int? id,
    String? title,
    int? amount,
    DateTime? date,
    int? categoryId,
    String? note,
    int? recurringId,
  }) {
    return Record(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'category_id': categoryId,
    'note': note,
    'recurring_id': recurringId,
  };

  factory Record.fromRow(Map<String, Object?> row) => Record(
    id: row['id'] as int?,
    title: row['title'] as String? ?? '',
    amount: row['amount'] as int,
    date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
    categoryId: row['category_id'] as int,
    note: row['note'] as String?,
    recurringId: row['recurring_id'] as int?,
  );
}
