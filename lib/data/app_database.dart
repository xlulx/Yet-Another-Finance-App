import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/debt.dart';
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
  /// 3: debts and their payments.
  static const _version = 5;

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
    }
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _onCreate(db, version, language);
          await _upgradeToV2(db, language);
          await _upgradeToV3(db);
          await _upgradeToV5(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _upgradeToV2(db, language);
          if (from < 3) await _upgradeToV3(db);
          if (from < 5) await _upgradeToV5(db);
        },
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
        name: language == 'tr' ? _defaultWallet.$2 : _defaultWallet.$1,
        color: 0xFF43A047,
        icon: 'cash',
      ).toRow()..remove('id'),
    );
    await db.update('records', {'wallet_id': id});
    await db.update('recurring_rules', {'wallet_id': id});
  }

  /// Adds debts (lent or borrowed) and their repayments.
  static Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        direction INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        due_date INTEGER,
        note TEXT,
        wallet_id INTEGER REFERENCES wallets(id),
        closed INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        wallet_id INTEGER REFERENCES wallets(id),
        note TEXT
      )''');
    await db.execute(
      'CREATE INDEX idx_debt_payments_debt ON debt_payments(debt_id)',
    );
  }

  /// When a debt was closed by hand. (Version 4 was a test build only.)
  static Future<void> _upgradeToV5(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(debts)');
    if (columns.any((c) => c['name'] == 'closed_at')) return;
    await db.execute('ALTER TABLE debts ADD COLUMN closed_at INTEGER');
  }

  /// Categories created on first launch: English name, Turkish name, type,
  /// colour, icon.
  static const _defaultCategories =
      <(String, String, CategoryType, int, String)>[
        ('Groceries', 'Market', CategoryType.expense, 0xFF66BB6A, 'cart'),
        (
          'Eating out',
          'Yeme-İçme',
          CategoryType.expense,
          0xFFFFA726,
          'restaurant',
        ),
        ('Transport', 'Ulaşım', CategoryType.expense, 0xFF42A5F5, 'car'),
        ('Bills', 'Faturalar', CategoryType.expense, 0xFFEF5350, 'bill'),
        ('Rent', 'Kira', CategoryType.expense, 0xFF8D6E63, 'home'),
        ('Health', 'Sağlık', CategoryType.expense, 0xFFEC407A, 'health'),
        ('Entertainment', 'Eğlence', CategoryType.expense, 0xFFAB47BC, 'movie'),
        ('Shopping', 'Alışveriş', CategoryType.expense, 0xFF26A69A, 'shopping'),
        ('Salary', 'Maaş', CategoryType.income, 0xFF43A047, 'work'),
        (
          'Other income',
          'Diğer Gelir',
          CategoryType.income,
          0xFF7CB342,
          'savings',
        ),
      ];

  /// The first wallet's name: English, Turkish.
  static const _defaultWallet = ('Cash', 'Nakit');

  static Future<void> _seedDefaultCategories(
    DatabaseExecutor db,
    String language,
  ) async {
    final tr = language == 'tr';
    for (final (i, (en, trName, type, color, icon))
        in _defaultCategories.indexed) {
      await db.insert(
        'categories',
        Category(
          name: tr ? trName : en,
          type: type,
          color: color,
          icon: icon,
          sortOrder: i,
        ).toRow(),
      );
    }
  }

  /// Renames the default categories and wallet into [language], leaving
  /// alone any the user renamed. Used when the language is chosen on the
  /// welcome screen, after they were created in the phone's language.
  Future<void> localizeDefaults(String language) async {
    final tr = language == 'tr';
    final names = [
      for (final (en, trName, _, _, _) in _defaultCategories) (en, trName),
    ];
    await db.transaction((txn) async {
      for (final (en, trName) in names) {
        await txn.update(
          'categories',
          {'name': tr ? trName : en},
          where: 'name = ?',
          whereArgs: [tr ? en : trName],
        );
      }
      final (en, trName) = _defaultWallet;
      await txn.update(
        'wallets',
        {'name': tr ? trName : en},
        where: 'name = ?',
        whereArgs: [tr ? en : trName],
      );
    });
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

  /// Number of records, recurring rules, transfers, debts and debt payments
  /// using the wallet.
  Future<int> walletUsage(int id) async {
    final rows = await db.rawQuery(
      '''SELECT
           (SELECT COUNT(*) FROM records WHERE wallet_id = ?1)
         + (SELECT COUNT(*) FROM recurring_rules WHERE wallet_id = ?1)
         + (SELECT COUNT(*) FROM transfers
              WHERE from_wallet_id = ?1 OR to_wallet_id = ?1)
         + (SELECT COUNT(*) FROM debts WHERE wallet_id = ?1)
         + (SELECT COUNT(*) FROM debt_payments WHERE wallet_id = ?1) AS n''',
      [id],
    );
    return rows.first['n'] as int;
  }

  /// Deletes an unused wallet (see [walletUsage]).
  Future<void> deleteWallet(int id) =>
      db.delete('wallets', where: 'id = ?', whereArgs: [id]);

  /// Current balance of every wallet: starting balance + income - expenses
  /// + transfers in - transfers out, and debts: money lent leaves the wallet
  /// and its repayments come back; money borrowed comes in and its
  /// repayments go out.
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
                    WHERE from_wallet_id = w.id), 0)
        + COALESCE((SELECT SUM(CASE WHEN direction = 0 THEN -amount
                                    ELSE amount END)
                    FROM debts WHERE wallet_id = w.id), 0)
        + COALESCE((SELECT SUM(CASE WHEN d.direction = 0 THEN p.amount
                                    ELSE -p.amount END)
                    FROM debt_payments p JOIN debts d ON d.id = p.debt_id
                    WHERE p.wallet_id = w.id), 0) AS balance
      FROM wallets w''');
    return {for (final r in rows) r['id'] as int: r['balance'] as int};
  }

  // ---- Debts ----

  Future<List<Debt>> debts() async {
    final rows = await db.query('debts', orderBy: 'date DESC, id DESC');
    return rows.map(Debt.fromRow).toList();
  }

  Future<List<DebtPayment>> debtPayments() async {
    final rows = await db.query('debt_payments', orderBy: 'date, id');
    return rows.map(DebtPayment.fromRow).toList();
  }

  Future<int> insertDebt(Debt d) => db.insert('debts', d.toRow()..remove('id'));

  Future<void> updateDebt(Debt d) =>
      db.update('debts', d.toRow(), where: 'id = ?', whereArgs: [d.id]);

  /// Deletes the debt and its payments.
  Future<void> deleteDebt(int id) =>
      db.delete('debts', where: 'id = ?', whereArgs: [id]);

  Future<int> insertDebtPayment(DebtPayment p) =>
      db.insert('debt_payments', p.toRow()..remove('id'));

  Future<void> deleteDebtPayment(int id) =>
      db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);

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

  /// Whether nothing was entered yet: no records, transfers, debts or
  /// recurring rules, and only the untouched first wallet.
  Future<bool> isUntouched() async {
    final rows = await db.rawQuery('''SELECT
        (SELECT COUNT(*) FROM records) + (SELECT COUNT(*) FROM transfers)
      + (SELECT COUNT(*) FROM debts) + (SELECT COUNT(*) FROM recurring_rules)
        AS entries,
        (SELECT COUNT(*) FROM wallets) AS wallets,
        (SELECT COUNT(*) FROM wallets WHERE initial_balance <> 0) AS funded''');
    final r = rows.first;
    return r['entries'] == 0 && r['wallets'] == 1 && r['funded'] == 0;
  }

  /// Every setting, read at once on start.
  Future<Map<String, String?>> settings() async => {
    for (final r in await db.query('settings'))
      r['key'] as String: r['value'] as String?,
  };

  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
