/// Which way the money went. The index is stored in the database: only
/// append.
enum DebtDirection {
  /// I lent money: they owe me.
  lent,

  /// I borrowed money: I owe them.
  borrowed,
}

/// Money lent to or borrowed from someone. Repaid with [DebtPayment]s.
///
/// When [walletId] is set, the money left (lent) or entered (borrowed) that
/// wallet; when null, the debt is only noted and changes no balance. Debts
/// are never income or expense.
class Debt {
  final int? id;
  final String person;
  final DebtDirection direction;

  /// Always positive, in minor units.
  final int amount;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final int? walletId;

  /// Closed by hand (e.g. forgiven) even if not fully repaid.
  final bool closed;

  const Debt({
    this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.date,
    this.dueDate,
    this.note,
    this.walletId,
    this.closed = false,
  });

  bool get lent => direction == DebtDirection.lent;

  Debt copyWith({bool? closed}) => Debt(
    id: id,
    person: person,
    direction: direction,
    amount: amount,
    date: date,
    dueDate: dueDate,
    note: note,
    walletId: walletId,
    closed: closed ?? this.closed,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'person': person,
    'direction': direction.index,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'due_date': dueDate?.millisecondsSinceEpoch,
    'note': note,
    'wallet_id': walletId,
    'closed': closed ? 1 : 0,
  };

  factory Debt.fromRow(Map<String, Object?> row) {
    final due = row['due_date'] as int?;
    return Debt(
      id: row['id'] as int?,
      person: row['person'] as String,
      direction: DebtDirection.values[row['direction'] as int],
      amount: row['amount'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      dueDate: due == null ? null : DateTime.fromMillisecondsSinceEpoch(due),
      note: row['note'] as String?,
      walletId: row['wallet_id'] as int?,
      closed: (row['closed'] as int? ?? 0) == 1,
    );
  }
}

/// A (partial) repayment of a [Debt]. For money lent it comes into
/// [walletId]; for money borrowed it goes out of it. Null: no wallet.
class DebtPayment {
  final int? id;
  final int debtId;
  final int amount;
  final DateTime date;
  final int? walletId;
  final String? note;

  /// Set when the debt was forgiven: the expense (money lent) or income
  /// (money borrowed) record it was written off as.
  final int? recordId;

  const DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.walletId,
    this.note,
    this.recordId,
  });

  bool get forgiven => recordId != null;

  Map<String, Object?> toRow() => {
    'id': id,
    'debt_id': debtId,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'wallet_id': walletId,
    'note': note,
    'record_id': recordId,
  };

  factory DebtPayment.fromRow(Map<String, Object?> row) => DebtPayment(
    id: row['id'] as int?,
    debtId: row['debt_id'] as int,
    amount: row['amount'] as int,
    date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
    walletId: row['wallet_id'] as int?,
    note: row['note'] as String?,
    recordId: row['record_id'] as int?,
  );
}

/// A debt being opened, or one of its payments, as it affects a wallet.
class DebtEvent {
  DebtEvent(this.debt, this.payment);

  final Debt debt;

  /// Null for the debt itself.
  final DebtPayment? payment;

  DateTime get date => payment?.date ?? debt.date;

  /// A forgiven amount: paired with a record that cancels it out.
  bool get forgiven => payment?.forgiven ?? false;
  int? get walletId => payment == null ? debt.walletId : payment!.walletId;

  /// Signed change to the wallet: lending takes money out and its
  /// repayments bring it back; borrowing is the other way round.
  int get effect {
    final amount = payment?.amount ?? debt.amount;
    final out = (payment == null) == debt.lent;
    return out ? -amount : amount;
  }
}
