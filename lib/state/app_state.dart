import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../data/app_database.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';
import '../models/transfer.dart';
import '../models/wallet.dart';
import '../services/backup.dart';
import '../services/oinkoin_import.dart';
import '../services/recurring_service.dart';
import '../utils/app_version.dart';

/// App state: categories, wallets, the selected month's records and
/// transfers, and recurring rules.
class AppState extends ChangeNotifier {
  AppState(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  List<Category> categories = [];
  List<RecurringRule> rules = [];
  List<Record> monthRecords = [];
  List<Transfer> monthTransfers = [];
  List<Wallet> wallets = [];

  /// Current balance per wallet id.
  Map<int, int> balances = {};

  /// Wallet shown on the records and statistics pages; null for all.
  int? walletFilter;
  late DateTime month = DateTime(_clock().year, _clock().month);
  String currency = '₺';

  /// Chosen UI language: `en`, `tr`, or empty to follow the system.
  String language = '';

  /// The locale forced by the user, or null to follow the system.
  Locale? get locale => language.isEmpty ? null : Locale(language);

  Map<int, Category> _byId = {};
  Category? categoryById(int id) => _byId[id];

  Map<int, Wallet> _walletsById = {};
  Wallet? walletById(int? id) => id == null ? null : _walletsById[id];

  List<Wallet> get activeWallets => wallets.where((w) => !w.archived).toList();

  /// Wallet preselected for new records: the filtered wallet, else the
  /// first active one.
  int get defaultWalletId =>
      walletFilter ??
      (activeWallets.isNotEmpty ? activeWallets.first : wallets.first).id!;

  /// Sum of all wallet balances.
  int get totalBalance => balances.values.fold(0, (a, b) => a + b);

  Future<void> load() async {
    currency = await db.getSetting('currency') ?? '₺';
    language = await db.getSetting('language') ?? '';
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
  }

  Future<void> _reloadAll() async {
    categories = await db.categories();
    _byId = {for (final c in categories) c.id!: c};
    rules = await db.recurringRules();
    wallets = await db.wallets();
    _walletsById = {for (final w in wallets) w.id!: w};
    if (walletFilter != null && !_walletsById.containsKey(walletFilter)) {
      walletFilter = null;
    }
    await _reloadMonth(notify: false);
    notifyListeners();
  }

  Future<void> _reloadMonth({bool notify = true}) async {
    final to = DateTime(month.year, month.month + 1);
    monthRecords = await db.records(
      from: month,
      to: to,
      walletId: walletFilter,
    );
    monthTransfers = await db.transfers(
      from: month,
      to: to,
      walletId: walletFilter,
    );
    balances = await db.walletBalances();
    if (notify) notifyListeners();
  }

  Future<void> setMonth(DateTime m) async {
    month = DateTime(m.year, m.month);
    await _reloadMonth();
  }

  Future<void> setWalletFilter(int? walletId) async {
    walletFilter = walletId;
    await _reloadMonth();
  }

  Future<void> shiftMonth(int delta) =>
      setMonth(DateTime(month.year, month.month + delta));

  // ---- Summary ----

  bool isIncome(Record r) => _byId[r.categoryId]?.type == CategoryType.income;

  int get monthIncome =>
      monthRecords.where(isIncome).fold(0, (sum, r) => sum + r.amount);

  int get monthExpense => monthRecords
      .where((r) => !isIncome(r))
      .fold(0, (sum, r) => sum + r.amount);

  /// Transfers into the filtered wallet this month; 0 without a filter
  /// (between all wallets, transfers cancel out).
  int get monthTransfersIn => walletFilter == null
      ? 0
      : monthTransfers
            .where((t) => t.toWalletId == walletFilter)
            .fold(0, (sum, t) => sum + t.amount);

  /// Transfers out of the filtered wallet this month; 0 without a filter.
  int get monthTransfersOut => walletFilter == null
      ? 0
      : monthTransfers
            .where((t) => t.fromWalletId == walletFilter)
            .fold(0, (sum, t) => sum + t.amount);

  /// Positive for income, negative for expenses.
  int signedAmount(Record r) => isIncome(r) ? r.amount : -r.amount;

  // ---- Records ----

  Future<void> saveRecord(Record r) async {
    if (r.id == null) {
      await db.insertRecord(r);
    } else {
      await db.updateRecord(r);
    }
    await _reloadMonth();
  }

  Future<void> deleteRecord(Record r) async {
    await db.deleteRecord(r.id!);
    await _reloadMonth();
  }

  // ---- Transfers ----

  Future<void> saveTransfer(Transfer t) async {
    if (t.id == null) {
      await db.insertTransfer(t);
    } else {
      await db.updateTransfer(t);
    }
    await _reloadMonth();
  }

  Future<void> deleteTransfer(Transfer t) async {
    await db.deleteTransfer(t.id!);
    await _reloadMonth();
  }

  /// Replaces a record with a transfer or the other way round, when the
  /// user switches the type while editing.
  Future<void> replaceEntry({
    Record? oldRecord,
    Transfer? oldTransfer,
    Record? newRecord,
    Transfer? newTransfer,
  }) async {
    await db.db.transaction((txn) async {
      if (oldRecord != null) {
        await txn.delete('records', where: 'id = ?', whereArgs: [oldRecord.id]);
      }
      if (oldTransfer != null) {
        await txn.delete(
          'transfers',
          where: 'id = ?',
          whereArgs: [oldTransfer.id],
        );
      }
      if (newRecord != null) await db.insertRecord(newRecord, txn: txn);
      if (newTransfer != null) await db.insertTransfer(newTransfer, txn: txn);
    });
    await _reloadMonth();
  }

  // ---- Wallets ----

  Future<void> saveWallet(Wallet w) async {
    if (w.id == null) {
      await db.insertWallet(w.copyWith(sortOrder: wallets.length));
    } else {
      await db.updateWallet(w);
    }
    await _reloadAll();
  }

  /// Deletes the wallet if nothing uses it; returns false otherwise.
  Future<bool> deleteWallet(Wallet w) async {
    if (wallets.length <= 1 || await db.walletUsage(w.id!) > 0) return false;
    await db.deleteWallet(w.id!);
    await _reloadAll();
    return true;
  }

  bool walletNameTaken(String name, {int? exceptId}) => wallets.any(
    (w) =>
        w.id != exceptId && w.name.toLowerCase() == name.trim().toLowerCase(),
  );

  // ---- Categories ----

  Future<void> saveCategory(Category c) async {
    if (c.id == null) {
      final sameType = categories.where((x) => x.type == c.type);
      await db.insertCategory(c.copyWith(sortOrder: sameType.length));
    } else {
      await db.updateCategory(c);
    }
    await _reloadAll();
  }

  Future<void> deleteCategory(Category c) async {
    await db.deleteCategory(c.id!);
    await _reloadAll();
  }

  bool categoryNameTaken(String name, CategoryType type, {int? exceptId}) =>
      categories.any(
        (c) =>
            c.type == type &&
            c.id != exceptId &&
            c.name.toLowerCase() == name.trim().toLowerCase(),
      );

  // ---- Recurring ----

  Future<int> saveRule(RecurringRule r) async {
    if (r.id == null) {
      await db.insertRecurringRule(r);
    } else {
      await db.updateRecurringRule(r);
    }
    final created = await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
    return created;
  }

  Future<void> deleteRule(RecurringRule r) async {
    await db.deleteRecurringRule(r.id!);
    await _reloadAll();
  }

  // ---- Settings / import ----

  Future<void> setLanguage(String code) async {
    language = code;
    await db.setSetting('language', code);
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    currency = symbol;
    await db.setSetting('currency', symbol);
    notifyListeners();
  }

  /// All data as the text of a backup file.
  Future<String> exportBackupText() => exportBackup(db, appVersion: appVersion);

  /// Replaces all data with [backup]'s, then catches up recurring records.
  Future<void> restoreFromBackup(YafaBackup backup) async {
    await restoreBackup(db, backup);
    currency = await db.getSetting('currency') ?? currency;
    walletFilter = null;
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
  }

  Future<ImportSummary> importOinkoin(String json) async {
    final backup = parseOinkoinBackup(json);
    final summary = await importOinkoinBackup(db, backup);
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
    return summary;
  }
}
