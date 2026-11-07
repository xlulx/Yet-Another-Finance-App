import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../data/app_database.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';
import '../services/oinkoin_import.dart';
import '../services/recurring_service.dart';

/// App state: categories, the selected month's records and recurring rules.
class AppState extends ChangeNotifier {
  AppState(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  List<Category> categories = [];
  List<RecurringRule> rules = [];
  List<Record> monthRecords = [];
  late DateTime month = DateTime(_clock().year, _clock().month);
  String currency = '₺';

  Map<int, Category> _byId = {};
  Category? categoryById(int id) => _byId[id];

  Future<void> load() async {
    currency = await db.getSetting('currency') ?? '₺';
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
  }

  Future<void> _reloadAll() async {
    categories = await db.categories();
    _byId = {for (final c in categories) c.id!: c};
    rules = await db.recurringRules();
    await _reloadMonth(notify: false);
    notifyListeners();
  }

  Future<void> _reloadMonth({bool notify = true}) async {
    monthRecords = await db.records(
      from: month,
      to: DateTime(month.year, month.month + 1),
    );
    if (notify) notifyListeners();
  }

  Future<void> setMonth(DateTime m) async {
    month = DateTime(m.year, m.month);
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

  /// Restores a deleted record (with the same id).
  Future<void> restoreRecord(Record r) async {
    await db.db.insert('records', r.toRow());
    await _reloadMonth();
  }

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

  Future<void> setCurrency(String symbol) async {
    currency = symbol;
    await db.setSetting('currency', symbol);
    notifyListeners();
  }

  Future<ImportSummary> importOinkoin(String json) async {
    final backup = parseOinkoinBackup(json);
    final summary = await importOinkoinBackup(db, backup);
    await generateDueRecurringRecords(db, _clock());
    await _reloadAll();
    return summary;
  }
}
