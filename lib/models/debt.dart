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

  /// Closed by hand (e.g. forgiven) even if not fully repaid. What was
  /// left then counts as an expense (money lent) or income (borrowed).
  final bool closed;

  /// When it was closed by hand; null for debts closed before this was
  /// kept.
  final DateTime? closedAt;

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
    this.closedAt,
  });

  bool get lent => direction == DebtDirection.lent;

  /// Closing sets [closedAt] to [at]; reopening clears it.
  Debt copyWith({bool? closed, DateTime? at}) => Debt(
    id: id,
    person: person,
    direction: direction,
    amount: amount,
    date: date,
    dueDate: dueDate,
    note: note,
    walletId: walletId,
    closed: closed ?? this.closed,
    closedAt: closed == null ? closedAt : (closed ? at : null),
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
    'closed_at': closedAt?.millisecondsSinceEpoch,
  };

  factory Debt.fromRow(Map<String, Object?> row) {
    final due = row['due_date'] as int?;
    final closedAt = row['closed_at'] as int?;
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
      closedAt: closedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(closedAt),
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

  const DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.walletId,
    this.note,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'debt_id': debtId,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'wallet_id': walletId,
    'note': note,
  };

  factory DebtPayment.fromRow(Map<String, Object?> row) => DebtPayment(
    id: row['id'] as int?,
    debtId: row['debt_id'] as int,
    amount: row['amount'] as int,
    date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
    walletId: row['wallet_id'] as int?,
    note: row['note'] as String?,
  );
}

/// Something that happened to a debt: opened, a repayment, or closed by
/// hand with money still owed.
class DebtEvent {
  DebtEvent(this.debt, this.payment) : closedRemaining = null, _closedOn = null;

  /// Closed with [remaining] still owed, on [on].
  DebtEvent.closed(this.debt, int remaining, DateTime on)
    : payment = null,
      closedRemaining = remaining,
      _closedOn = on;

  final Debt debt;

  /// Null for the debt itself and for closing.
  final DebtPayment? payment;

  /// What was still owed when the debt was closed by hand.
  final int? closedRemaining;
  final DateTime? _closedOn;

  bool get isClosing => closedRemaining != null;

  /// Only closing with money still owed is a real loss (money lent) or
  /// gain (money borrowed); lending, borrowing and repaying are not income
  /// or expense.
  bool get counts => isClosing;

  DateTime get date => _closedOn ?? payment?.date ?? debt.date;
  int? get walletId => payment == null ? debt.walletId : payment!.walletId;

  /// Signed change: for opening and repayments, to the wallet (lending
  /// takes money out and its repayments bring it back; borrowing is the
  /// other way round). For closing, the loss or gain.
  int get effect {
    if (isClosing) return debt.lent ? -closedRemaining! : closedRemaining!;
    final amount = payment?.amount ?? debt.amount;
    final out = (payment == null) == debt.lent;
    return out ? -amount : amount;
  }
}
