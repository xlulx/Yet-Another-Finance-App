import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show ChangeNotifier, listEquals;

import '../data/app_database.dart';
import '../l10n/app_localizations.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';
import '../models/transfer.dart';
import '../models/wallet.dart';
import '../services/auto_backup.dart';
import '../services/backup.dart';
import '../services/csv_export.dart';
import '../services/oinkoin_import.dart';
import '../services/recurring_service.dart';
import '../services/reminders.dart';
import '../utils/app_version.dart';

/// App state: categories, wallets, the selected month's records and
/// transfers, and recurring rules.
class AppState extends ChangeNotifier {
  AppState(
    this.db, {
    DateTime Function()? clock,
    this.backupWriter = const PlatformBackupWriter(),
    this.reminderScheduler = const NoReminderScheduler(),
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;

  /// Where automatic backups are written; replaced in tests.
  final BackupWriter backupWriter;

  /// Shows reminder notifications; does nothing unless given (tests).
  final ReminderScheduler reminderScheduler;
  final DateTime Function() _clock;

  List<Category> categories = [];
  List<RecurringRule> rules = [];
  List<Record> monthRecords = [];
  List<Transfer> monthTransfers = [];
  List<Wallet> wallets = [];

  /// Current balance per wallet id.
  Map<int, int> balances = {};

  List<Debt> debts = [];
  Map<int, List<DebtPayment>> _payments = {};

  /// Debt movements that touched a wallet in the selected month (and the
  /// filtered wallet, if any), for the records page.
  List<DebtEvent> monthDebtEvents = [];

  /// Wallet shown on the records and statistics pages; null for all.
  int? walletFilter;
  late DateTime month = DateTime(_clock().year, _clock().month);
  String currency = '₺';

  AutoBackupFrequency autoBackup = AutoBackupFrequency.off;
  DateTime? lastAutoBackup;

  /// Folder of the last automatic backup, if one ran since app start.
  String? autoBackupLocation;

  /// Why the last automatic backup failed, if it did.
  String? autoBackupError;

  /// Reminders on the day of recurring records and debt due dates.
  bool remindRecurring = false;
  bool remindDebts = false;
  int remindHour = 9;
  int remindMinute = 0;

  /// What is scheduled now, to skip rescheduling when nothing changed.
  List<Reminder> _scheduled = const [];

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
    autoBackup = parseFrequency(await db.getSetting(autoBackupKey));
    lastAutoBackup = DateTime.tryParse(
      await db.getSetting(autoBackupLastKey) ?? '',
    );
    remindRecurring = await db.getSetting(remindRecurringKey) == '1';
    remindDebts = await db.getSetting(remindDebtsKey) == '1';
    final time = (await db.getSetting(remindTimeKey) ?? '').split(':');
    if (time.length == 2) {
      remindHour = int.tryParse(time[0]) ?? remindHour;
      remindMinute = int.tryParse(time[1]) ?? remindMinute;
    }
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
    await autoBackupIfDue();
  }

  /// Called when the app comes back to the foreground.
  Future<void> onResume() async {
    await autoBackupIfDue();
    await syncReminders();
  }

  // ---- Reminders ----

  /// Schedules the reminders that are due from now on, replacing the old
  /// ones. Never throws.
  Future<void> syncReminders() async {
    final code = language.isNotEmpty
        ? language
        : PlatformDispatcher.instance.locale.languageCode;
    final l = lookupAppLocalizations(Locale(code == 'tr' ? 'tr' : 'en'));
    final next = upcomingReminders(
      now: _clock(),
      hour: remindHour,
      minute: remindMinute,
      l: l,
      currency: currency,
      rules: remindRecurring ? rules : const [],
      categories: _byId,
      debts: remindDebts ? debts : const [],
      remainingOf: remainingOf,
      isSettled: isSettled,
    );
    if (listEquals(next, _scheduled)) return;
    try {
      await reminderScheduler.replaceAll(next, l);
      _scheduled = next;
    } catch (_) {
      // Reminders are a convenience; a failure must not break the app.
    }
  }

  /// Turns reminders for recurring records or debts on or off. Turning one
  /// on asks for permission first; returns false if it was refused.
  Future<bool> setReminders({bool? recurring, bool? debts}) async {
    if ((recurring ?? false) || (debts ?? false)) {
      var granted = false;
      try {
        granted = await reminderScheduler.requestPermission();
      } catch (_) {}
      if (!granted) return false;
    }
    if (recurring != null) {
      remindRecurring = recurring;
      await db.setSetting(remindRecurringKey, recurring ? '1' : '0');
    }
    if (debts != null) {
      remindDebts = debts;
      await db.setSetting(remindDebtsKey, debts ? '1' : '0');
    }
    notifyListeners();
    await syncReminders();
    return true;
  }

  Future<void> setReminderTime(int hour, int minute) async {
    remindHour = hour;
    remindMinute = minute;
    final hh = '$hour'.padLeft(2, '0'), mm = '$minute'.padLeft(2, '0');
    await db.setSetting(remindTimeKey, '$hh:$mm');
    notifyListeners();
    await syncReminders();
  }

  /// Takes an automatic backup if one is due. Called on start and whenever
  /// the app comes back to the foreground. Never throws: failures are kept
  /// in [autoBackupError] and shown in Settings.
  Future<void> autoBackupIfDue() async {
    if (autoBackup == AutoBackupFrequency.off) return;
    try {
      final where = await runAutoBackupIfDue(
        db,
        backupWriter,
        _clock(),
        appVersion: appVersion,
      );
      if (where == null) return;
      lastAutoBackup = _clock();
      // Show the folder; the file name is long and changes every time.
      final slash = where.lastIndexOf('/');
      autoBackupLocation = slash > 0 ? where.substring(0, slash) : where;
      autoBackupError = null;
    } catch (e) {
      autoBackupError = '$e';
    }
    notifyListeners();
  }

  /// Turns automatic backups on or off; when turned on, backs up right away
  /// if one is due (always the case the first time).
  Future<void> setAutoBackup(AutoBackupFrequency frequency) async {
    autoBackup = frequency;
    autoBackupError = null;
    await db.setSetting(autoBackupKey, frequency.name);
    notifyListeners();
    await autoBackupIfDue();
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
    debts = await db.debts();
    _payments = {};
    forgivenRecords = {};
    for (final p in await db.debtPayments()) {
      _payments.putIfAbsent(p.debtId, () => []).add(p);
      if (p.recordId != null) forgivenRecords[p.recordId!] = p.debtId;
    }
    monthDebtEvents = [
      for (final e in allDebtEvents())
        if (!e.date.isBefore(month) &&
            e.date.isBefore(to) &&
            e.walletId != null &&
            // The forgiveness record is listed instead.
            !e.forgiven &&
            (walletFilter == null || e.walletId == walletFilter))
          e,
    ];
    await syncReminders();
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

  // ---- Debts ----

  List<DebtPayment> paymentsOf(Debt d) => _payments[d.id] ?? const [];

  /// Repaid, not counting what was forgiven.
  int paidOf(Debt d) =>
      paymentsOf(d).where((p) => !p.forgiven).fold(0, (s, p) => s + p.amount);
  int forgivenOf(Debt d) =>
      paymentsOf(d).where((p) => p.forgiven).fold(0, (s, p) => s + p.amount);
  int remainingOf(Debt d) => d.amount - paidOf(d) - forgivenOf(d);

  /// Records written for forgiven debts, by record id: the debt's id.
  Map<int, int> forgivenRecords = {};

  /// The category last used for forgiving debts of this kind (expense for
  /// money lent, income for money borrowed), if it still exists.
  Future<int?> forgiveCategoryId(CategoryType type) async {
    final id = int.tryParse(
      await db.getSetting('$_forgiveCategoryKey${type.index}') ?? '',
    );
    return _byId[id]?.type == type ? id : null;
  }

  static const _forgiveCategoryKey = 'forgive_category_';

  /// Forgives [amount] of [debt] (see [AppDatabase.forgiveDebt]). Without
  /// a [categoryId], a category named [newCategoryName] is created.
  Future<void> forgiveDebt(
    Debt debt, {
    required int amount,
    required int walletId,
    required DateTime date,
    int? categoryId,
    required String newCategoryName,
  }) async {
    final type = debt.lent ? CategoryType.expense : CategoryType.income;
    categoryId ??= await db.insertCategory(
      Category(
        name: newCategoryName,
        type: type,
        color: 0xFF78909C,
        icon: 'handshake',
        sortOrder: categories.where((c) => c.type == type).length,
      ),
    );
    await db.setSetting('$_forgiveCategoryKey${type.index}', '$categoryId');
    await db.forgiveDebt(
      debt,
      amount: amount,
      categoryId: categoryId,
      walletId: walletId,
      date: date,
    );
    await _reloadAll();
  }

  /// Fully repaid, or closed by hand.
  bool isSettled(Debt d) => d.closed || remainingOf(d) <= 0;

  /// What others still owe me, across open debts.
  int get totalOwedToMe => debts
      .where((d) => d.lent && !isSettled(d))
      .fold(0, (s, d) => s + remainingOf(d));

  /// What I still owe others, across open debts.
  int get totalIOwe => debts
      .where((d) => !d.lent && !isSettled(d))
      .fold(0, (s, d) => s + remainingOf(d));

  /// Names already used, for suggestions when adding a debt.
  List<String> get debtPeople {
    final seen = <String>{};
    return [
      for (final d in debts)
        if (seen.add(d.person.toLowerCase())) d.person,
    ];
  }

  /// Every debt and payment, with or without a wallet.
  Iterable<DebtEvent> allDebtEvents() sync* {
    for (final d in debts) {
      yield DebtEvent(d, null);
      for (final p in paymentsOf(d)) {
        yield DebtEvent(d, p);
      }
    }
  }

  /// Debt money into the filtered wallet this month; 0 without a filter.
  int get monthDebtIn => walletFilter == null
      ? 0
      : monthDebtEvents
            .where((e) => e.effect > 0)
            .fold(0, (s, e) => s + e.effect);

  /// Debt money out of the filtered wallet this month; 0 without a filter.
  int get monthDebtOut => walletFilter == null
      ? 0
      : monthDebtEvents
            .where((e) => e.effect < 0)
            .fold(0, (s, e) => s - e.effect);

  Future<void> saveDebt(Debt d) async {
    if (d.id == null) {
      await db.insertDebt(d);
    } else {
      await db.updateDebt(d);
    }
    await _reloadMonth();
  }

  Future<void> deleteDebt(Debt d) async {
    await db.deleteDebt(d.id!);
    await _reloadMonth();
  }

  Future<void> setDebtClosed(Debt d, bool closed) =>
      saveDebt(d.copyWith(closed: closed));

  Future<void> addDebtPayment(DebtPayment p) async {
    await db.insertDebtPayment(p);
    await _reloadMonth();
  }

  Future<void> deleteDebtPayment(DebtPayment p) async {
    await db.deleteDebtPayment(p.id!);
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
    await syncReminders();
  }

  Future<void> setCurrency(String symbol) async {
    currency = symbol;
    await db.setSetting('currency', symbol);
    notifyListeners();
    await syncReminders();
  }

  /// All records, transfers and debt movements as CSV text.
  Future<String> exportCsvText(CsvLabels labels) async => exportCsv(
    records: await db.records(),
    transfers: await db.transfers(),
    debtEvents: allDebtEvents(),
    categories: _byId,
    wallets: _walletsById,
    currency: currency,
    labels: labels,
  );

  /// All data as the text of a backup file.
  Future<String> exportBackupText() => exportBackup(db, appVersion: appVersion);

  /// Replaces all data with [backup]'s, then catches up recurring records.
  Future<void> restoreFromBackup(YasbaBackup backup) async {
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
