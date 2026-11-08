import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/debt.dart';
import '../models/record.dart';
import '../models/transfer.dart';
import '../models/wallet.dart';

/// Column titles and type names, in the user's language.
class CsvLabels {
  const CsvLabels({
    required this.headers,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.debtLent,
    required this.debtBorrowed,
    required this.repaymentReceived,
    required this.repaymentMade,
  });

  /// Date, type, category, wallet, to wallet, title, note, amount, currency.
  final List<String> headers;
  final String income;
  final String expense;
  final String transfer;
  final String debtLent;
  final String debtBorrowed;
  final String repaymentReceived;
  final String repaymentMade;
}

/// All records, transfers and debt movements as CSV, oldest first, for
/// spreadsheets.
///
/// Amounts use a dot as decimal separator and are signed: income positive,
/// expenses negative; transfers are positive with both wallets named. Debt
/// movements are signed by their effect on the wallet (lending is negative,
/// its repayments positive) and name the person as title. The
/// text starts with a byte order mark so Excel reads it as UTF-8.
String exportCsv({
  required Iterable<Record> records,
  required Iterable<Transfer> transfers,
  Iterable<DebtEvent> debtEvents = const [],
  required Map<int, Category> categories,
  required Map<int, Wallet> wallets,
  required String currency,
  required CsvLabels labels,
}) {
  final date = DateFormat('yyyy-MM-dd HH:mm');
  String amount(int cents) => (cents / 100).toStringAsFixed(2);
  final rows = <(DateTime, List<String>)>[
    for (final r in records)
      () {
        final c = categories[r.categoryId];
        final income = c?.type == CategoryType.income;
        return (
          r.date,
          [
            date.format(r.date),
            income ? labels.income : labels.expense,
            c?.name ?? '',
            wallets[r.walletId]?.name ?? '',
            '',
            r.title,
            r.note ?? '',
            amount(income ? r.amount : -r.amount),
            currency,
          ],
        );
      }(),
    for (final t in transfers)
      (
        t.date,
        [
          date.format(t.date),
          labels.transfer,
          '',
          wallets[t.fromWalletId]?.name ?? '',
          wallets[t.toWalletId]?.name ?? '',
          '',
          t.note ?? '',
          amount(t.amount),
          currency,
        ],
      ),
    for (final e in debtEvents)
      (
        e.date,
        [
          date.format(e.date),
          switch ((e.payment == null, e.debt.lent)) {
            (true, true) => labels.debtLent,
            (true, false) => labels.debtBorrowed,
            (false, true) => labels.repaymentReceived,
            (false, false) => labels.repaymentMade,
          },
          '',
          wallets[e.walletId]?.name ?? '',
          '',
          e.debt.person,
          (e.payment == null ? e.debt.note : e.payment!.note) ?? '',
          amount(e.effect),
          currency,
        ],
      ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final out = StringBuffer('﻿')..writeln(_line(labels.headers));
  for (final (_, cells) in rows) {
    out.writeln(_line(cells));
  }
  return out.toString();
}

String _line(List<String> cells) => cells.map(_cell).join(',');

/// Quotes a cell when it contains a comma, quote or line break.
String _cell(String v) {
  if (!v.contains(RegExp(r'[",\r\n]'))) return v;
  return '"${v.replaceAll('"', '""')}"';
}
