import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';

/// SQLite access layer. All data stays on the device.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _version = 1;

  /// Opens the app database. Tests can pass a [factory] and [path]
  /// (e.g. `databaseFactoryFfi` and `inMemoryDatabasePath`).
  ///
  /// [language] picks the names of the default categories created on first
  /// launch (`tr` or anything else for English).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    String language = 'en',
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'yafa.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _onCreate(db, version, language),
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(
    Database db,
    int version,
    String language,
  ) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        emoji TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        UNIQUE(name, type)
      )''');
    await db.execute('''
      CREATE TABLE recurring_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        note TEXT,
        start_date INTEGER NOT NULL,
        interval INTEGER NOT NULL,
        unit INTEGER NOT NULL,
        end_date INTEGER,
        last_generated INTEGER
      )''');
    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        note TEXT,
        recurring_id INTEGER REFERENCES recurring_rules(id) ON DELETE SET NULL
      )''');
    await db.execute('CREATE INDEX idx_records_date ON records(date)');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await _seedDefaultCategories(db, language);
    await db.insert('settings', {
      'key': 'currency',
      'value': language == 'tr' ? '₺' : r'$',
    });
  }

  static Future<void> _seedDefaultCategories(
    DatabaseExecutor db,
    String language,
  ) async {
    final tr = language == 'tr';
    final defaults = <(String, CategoryType, int, String)>[
      (tr ? 'Market' : 'Groceries', CategoryType.expense, 0xFF66BB6A, 'cart'),
      (
        tr ? 'Yeme-İçme' : 'Eating out',
        CategoryType.expense,
        0xFFFFA726,
        'restaurant',
      ),
      (tr ? 'Ulaşım' : 'Transport', CategoryType.expense, 0xFF42A5F5, 'car'),
      (tr ? 'Faturalar' : 'Bills', CategoryType.expense, 0xFFEF5350, 'bill'),
      (tr ? 'Kira' : 'Rent', CategoryType.expense, 0xFF8D6E63, 'home'),
      (tr ? 'Sağlık' : 'Health', CategoryType.expense, 0xFFEC407A, 'health'),
      (
        tr ? 'Eğlence' : 'Entertainment',
        CategoryType.expense,
        0xFFAB47BC,
        'movie',
      ),
      (
        tr ? 'Alışveriş' : 'Shopping',
        CategoryType.expense,
        0xFF26A69A,
        'shopping',
      ),
      (tr ? 'Maaş' : 'Salary', CategoryType.income, 0xFF43A047, 'work'),
      (
        tr ? 'Diğer Gelir' : 'Other income',
        CategoryType.income,
        0xFF7CB342,
        'savings',
      ),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final (name, type, color, icon) = defaults[i];
      await db.insert(
        'categories',
        Category(
          name: name,
          type: type,
          color: color,
          icon: icon,
          sortOrder: i,
        ).toRow(),
      );
    }
  }

  Future<void> close() => db.close();

  // ---- Categories ----

  Future<List<Category>> categories({DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query(
      'categories',
      orderBy: 'type, sort_order, name COLLATE NOCASE',
    );
    return rows.map(Category.fromRow).toList();
  }

  Future<int> insertCategory(Category c, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('categories', c.toRow()..remove('id'));

  Future<void> updateCategory(Category c) =>
      db.update('categories', c.toRow(), where: 'id = ?', whereArgs: [c.id]);

  /// Deletes the category and all of its records.
  Future<void> deleteCategory(int id) =>
      db.delete('categories', where: 'id = ?', whereArgs: [id]);

  // ---- Records ----

  /// Records in [from, to), newest first.
  Future<List<Record>> records({DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query(
      'records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Record.fromRow).toList();
  }

  Future<int> insertRecord(Record r, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('records', r.toRow()..remove('id'));

  Future<void> updateRecord(Record r) =>
      db.update('records', r.toRow(), where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteRecord(int id) =>
      db.delete('records', where: 'id = ?', whereArgs: [id]);

  // ---- Recurring rules ----

  Future<List<RecurringRule>> recurringRules({DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query(
      'recurring_rules',
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map(RecurringRule.fromRow).toList();
  }

  Future<int> insertRecurringRule(RecurringRule r, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('recurring_rules', r.toRow()..remove('id'));

  Future<void> updateRecurringRule(RecurringRule r, {DatabaseExecutor? txn}) =>
      (txn ?? db).update(
        'recurring_rules',
        r.toRow(),
        where: 'id = ?',
        whereArgs: [r.id],
      );

  /// Deletes the rule. Records it already generated are kept.
  Future<void> deleteRecurringRule(int id) =>
      db.delete('recurring_rules', where: 'id = ?', whereArgs: [id]);

  // ---- Settings ----

  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
