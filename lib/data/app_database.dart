import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';
import '../models/transfer.dart';
import '../models/wallet.dart';

/// SQLite access layer. All data stays on the device.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// 1: categories, records, recurring rules, settings.
  /// 2: wallets and transfers.
  static const _version = 2;

  /// Opens the app database. Tests can pass a [factory] and [path]
  /// (e.g. `databaseFactoryFfi` and `inMemoryDatabasePath`), or a
  /// [directory] to use instead of the platform's database folder.
  ///
  /// [language] picks the names of the default categories created on first
  /// launch (`tr` or anything else for English).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    String? directory,
    String language = 'en',
  }) async {
    final f = factory ?? databaseFactory;
    var dbPath = path;
    if (dbPath == null) {
      final dir = directory ?? await f.getDatabasesPath();
      dbPath = p.join(dir, 'yasba.db');
      await _moveOldDatabase(f, p.join(dir, 'yafa.db'), dbPath);
    }
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _onCreate(db, version, language);
          await _upgradeToV2(db, language);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _upgradeToV2(db, language);
        },
      ),
    );
    return AppDatabase._(db);
  }

  /// The app was called YAFA and kept its data in `yafa.db`; move it to the
  /// new name once, with SQLite's side files, so no data is lost.
  static Future<void> _moveOldDatabase(
    DatabaseFactory f,
    String oldPath,
    String newPath,
  ) async {
    if (!await f.databaseExists(oldPath) || await f.databaseExists(newPath)) {
      return;
    }
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final file = File('$oldPath$suffix');
      if (await file.exists()) await file.rename('$newPath$suffix');
    }
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

  /// Adds wallets and transfers. Existing records and recurring rules are
  /// moved to a new default wallet ("Cash" / "Nakit").
  static Future<void> _upgradeToV2(Database db, String language) async {
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        initial_balance INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    // Wallets referenced by records or transfers cannot be deleted (no
    // ON DELETE action), which protects against losing history.
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_wallet_id INTEGER NOT NULL REFERENCES wallets(id),
        to_wallet_id INTEGER NOT NULL REFERENCES wallets(id),
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        CHECK (from_wallet_id <> to_wallet_id)
      )''');
    await db.execute('CREATE INDEX idx_transfers_date ON transfers(date)');
    await db.execute(
      'ALTER TABLE records ADD COLUMN wallet_id INTEGER REFERENCES wallets(id)',
    );
    await db.execute(
      'ALTER TABLE recurring_rules '
      'ADD COLUMN wallet_id INTEGER REFERENCES wallets(id)',
    );
    await db.execute('CREATE INDEX idx_records_wallet ON records(wallet_id)');
    final id = await db.insert(
      'wallets',
      Wallet(
        name: language == 'tr' ? 'Nakit' : 'Cash',
        color: 0xFF43A047,
        icon: 'cash',
      ).toRow()..remove('id'),
    );
    await db.update('records', {'wallet_id': id});
    await db.update('recurring_rules', {'wallet_id': id});
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

  /// Records in [from, to), newest first; only [walletId]'s if given.
  Future<List<Record>> records({
    DateTime? from,
    DateTime? to,
    int? walletId,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (walletId != null) {
      where.add('wallet_id = ?');
      args.add(walletId);
    }
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

  Future<int> insertRecord(Record r, {DatabaseExecutor? txn}) async {
    final row = r.toRow()..remove('id');
    row['wallet_id'] ??= await defaultWalletId(txn: txn);
    return (txn ?? db).insert('records', row);
  }

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

  Future<int> insertRecurringRule(
    RecurringRule r, {
    DatabaseExecutor? txn,
  }) async {
    final row = r.toRow()..remove('id');
    row['wallet_id'] ??= await defaultWalletId(txn: txn);
    return (txn ?? db).insert('recurring_rules', row);
  }

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

  // ---- Wallets ----

  Future<List<Wallet>> wallets({DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query(
      'wallets',
      orderBy: 'archived, sort_order, id',
    );
    return rows.map(Wallet.fromRow).toList();
  }

  /// The first active wallet; used when a record has no wallet.
  Future<int> defaultWalletId({DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query(
      'wallets',
      columns: ['id'],
      orderBy: 'archived, sort_order, id',
      limit: 1,
    );
    return rows.first['id'] as int;
  }

  Future<int> insertWallet(Wallet w, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('wallets', w.toRow()..remove('id'));

  Future<void> updateWallet(Wallet w) =>
      db.update('wallets', w.toRow(), where: 'id = ?', whereArgs: [w.id]);

  /// Number of records, recurring rules and transfers using the wallet.
  Future<int> walletUsage(int id) async {
    final rows = await db.rawQuery(
      '''SELECT
           (SELECT COUNT(*) FROM records WHERE wallet_id = ?1)
         + (SELECT COUNT(*) FROM recurring_rules WHERE wallet_id = ?1)
         + (SELECT COUNT(*) FROM transfers
              WHERE from_wallet_id = ?1 OR to_wallet_id = ?1) AS n''',
      [id],
    );
    return rows.first['n'] as int;
  }

  /// Deletes an unused wallet (see [walletUsage]).
  Future<void> deleteWallet(int id) =>
      db.delete('wallets', where: 'id = ?', whereArgs: [id]);

  /// Current balance of every wallet: starting balance + income - expenses
  /// + transfers in - transfers out.
  Future<Map<int, int>> walletBalances() async {
    final rows = await db.rawQuery('''
      SELECT w.id,
        w.initial_balance
        + COALESCE((SELECT SUM(CASE WHEN c.type = 1 THEN r.amount
                                    ELSE -r.amount END)
                    FROM records r JOIN categories c ON c.id = r.category_id
                    WHERE r.wallet_id = w.id), 0)
        + COALESCE((SELECT SUM(amount) FROM transfers
                    WHERE to_wallet_id = w.id), 0)
        - COALESCE((SELECT SUM(amount) FROM transfers
                    WHERE from_wallet_id = w.id), 0) AS balance
      FROM wallets w''');
    return {for (final r in rows) r['id'] as int: r['balance'] as int};
  }

  // ---- Transfers ----

  /// Transfers in [from, to), newest first; only those touching [walletId]
  /// if given.
  Future<List<Transfer>> transfers({
    DateTime? from,
    DateTime? to,
    int? walletId,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (walletId != null) {
      where.add('(from_wallet_id = ? OR to_wallet_id = ?)');
      args.addAll([walletId, walletId]);
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query(
      'transfers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transfer.fromRow).toList();
  }

  Future<int> insertTransfer(Transfer t, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('transfers', t.toRow()..remove('id'));

  Future<void> updateTransfer(Transfer t) =>
      db.update('transfers', t.toRow(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTransfer(int id) =>
      db.delete('transfers', where: 'id = ?', whereArgs: [id]);

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
