/// Money moved from one wallet to another. Transfers change wallet balances
/// but are neither income nor expense.
class Transfer {
  final int? id;
  final int fromWalletId;
  final int toWalletId;

  /// Always positive, in minor units.
  final int amount;
  final DateTime date;
  final String? note;

  const Transfer({
    this.id,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'from_wallet_id': fromWalletId,
    'to_wallet_id': toWalletId,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'note': note,
  };

  factory Transfer.fromRow(Map<String, Object?> row) => Transfer(
    id: row['id'] as int?,
    fromWalletId: row['from_wallet_id'] as int,
    toWalletId: row['to_wallet_id'] as int,
    amount: row['amount'] as int,
    date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
    note: row['note'] as String?,
  );
}
