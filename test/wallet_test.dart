import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yafa/data/app_database.dart';
import 'package:yafa/models/category.dart';
import 'package:yafa/models/record.dart';
import 'package:yafa/models/recurring_rule.dart';
import 'package:yafa/models/transfer.dart';
import 'package:yafa/models/wallet.dart';
import 'package:yafa/services/oinkoin_import.dart';
import 'package:yafa/services/stats.dart';
import 'package:yafa/state/app_state.dart';

Future<AppDatabase> openMemory() => AppDatabase.open(
  factory: databaseFactoryFfiNoIsolate,
  path: inMemoryDatabasePath,
  language: 'tr',
);

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrading a version 1 database moves everything to a default '
      'wallet', () async {
    final dir = await Directory.systemTemp.createTemp('yafa');
    final path = '${dir.path}/v1.db';
    // The schema as shipped in v0.1/v0.2 (database version 1).
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
            type INTEGER NOT NULL, color INTEGER NOT NULL, icon TEXT NOT NULL,
            emoji TEXT, archived INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0, UNIQUE(name, type))''');
          await db.execute(
            '''CREATE TABLE recurring_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            amount INTEGER NOT NULL, category_id INTEGER NOT NULL
              REFERENCES categories(id) ON DELETE CASCADE,
            note TEXT, start_date INTEGER NOT NULL, interval INTEGER NOT NULL,
            unit INTEGER NOT NULL, end_date INTEGER, last_generated INTEGER)''',
          );
          await db.execute('''CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            amount INTEGER NOT NULL, date INTEGER NOT NULL,
            category_id INTEGER NOT NULL
              REFERENCES categories(id) ON DELETE CASCADE,
            note TEXT, recurring_id INTEGER
              REFERENCES recurring_rules(id) ON DELETE SET NULL)''');
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.insert('categories', {
            'name': 'Maaş',
            'type': 1,
            'color': 0xFF43A047,
            'icon': 'work',
          });
          await db.insert('recurring_rules', {
            'title': 'Maaş',
            'amount': 100000,
            'category_id': 1,
            'start_date': DateTime(2025).millisecondsSinceEpoch,
            'interval': 1,
            'unit': 2,
          });
          await db.insert('records', {
            'title': 'Maaş',
            'amount': 100000,
            'date': DateTime(2025).millisecondsSinceEpoch,
            'category_id': 1,
          });
        },
      ),
    );
    await v1.close();

    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      language: 'tr',
    );
    final wallets = await db.wallets();
    expect(wallets.map((w) => w.name), ['Nakit']);
    final cash = wallets.single.id;
    expect((await db.records()).single.walletId, cash);
    expect((await db.recurringRules()).single.walletId, cash);
    expect(await db.walletBalances(), {cash: 100000});
    await db.close();
    await dir.delete(recursive: true);
  });

  group('wallets and transfers', () {
    late AppDatabase db;
    late int cash, bank;
    late Category salary, market;

    setUp(() async {
      db = await openMemory();
      cash = (await db.wallets()).single.id!;
      bank = await db.insertWallet(
        const Wallet(name: 'Banka', color: 0xFF42A5F5, initialBalance: 1000),
      );
      final cats = await db.categories();
      salary = cats.firstWhere((c) => c.name == 'Maaş');
      market = cats.firstWhere((c) => c.name == 'Market');
    });
    tearDown(() => db.close());

    test('a fresh database has one default wallet', () async {
      final fresh = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${(await Directory.systemTemp.createTemp('yafa')).path}/f.db',
      );
      expect((await fresh.wallets()).map((w) => w.name), ['Cash']);
      await fresh.close();
    });

    test('records without a wallet go to the default wallet', () async {
      await db.insertRecord(
        Record(
          title: '',
          amount: 1,
          date: DateTime(2025),
          categoryId: market.id!,
        ),
      );
      expect((await db.records()).single.walletId, cash);
    });

    test('balances combine starting balance, records and transfers', () async {
      Future<void> add(Category c, int amount, int wallet) => db.insertRecord(
        Record(
          title: '',
          amount: amount,
          date: DateTime(2025, 1, 5),
          categoryId: c.id!,
          walletId: wallet,
        ),
      );
      await add(salary, 50000, bank);
      await add(market, 2000, bank);
      await add(market, 300, cash);
      await db.insertTransfer(
        Transfer(
          fromWalletId: bank,
          toWalletId: cash,
          amount: 5000,
          date: DateTime(2025, 1, 6),
        ),
      );
      final b = await db.walletBalances();
      expect(b[bank], 1000 + 50000 - 2000 - 5000);
      expect(b[cash], -300 + 5000);

      // Filters: the bank sees its own records and the transfer.
      expect(await db.records(walletId: bank), hasLength(2));
      expect(await db.records(walletId: cash), hasLength(1));
      expect(await db.transfers(walletId: cash), hasLength(1));
      expect(
        await db.transfers(walletId: bank, from: DateTime(2025, 2)),
        isEmpty,
      );
    });

    test('one wallet\'s statistics include its transfers', () async {
      Transfer t(int from, int to, int amount, int day) => Transfer(
        fromWalletId: from,
        toWalletId: to,
        amount: amount,
        date: DateTime(2025, 1, day),
      );
      final card = await db.insertWallet(
        const Wallet(name: 'Kart', color: 0xFF5C6BC0),
      );
      final transfers = [
        t(bank, cash, 1000, 1),
        t(bank, cash, 500, 2),
        t(bank, card, 300, 2),
        t(cash, bank, 200, 3),
      ];
      // Bank: money out per destination, largest first; money in per source.
      expect(transferTotals(transfers, bank, CategoryType.expense), [
        (cash, 1500, 2),
        (card, 300, 1),
      ]);
      expect(transferTotals(transfers, bank, CategoryType.income), [
        (cash, 200, 1),
      ]);
      expect(transferTotals(transfers, card, CategoryType.expense), isEmpty);

      final byId = {for (final c in await db.categories()) c.id!: c};
      final record = Record(
        title: '',
        amount: 50,
        date: DateTime(2025, 1, 2),
        categoryId: market.id!,
      );
      final days = bucketTotals(
        [record],
        byId,
        3,
        (d) => d.day - 1,
        transfers: transfers,
        walletId: bank,
      );
      expect(days, [(0, 1000), (0, 50 + 500 + 300), (200, 0)]);
      // Without a wallet, transfers are left out.
      expect(
        bucketTotals([record], byId, 3, (d) => d.day - 1, transfers: transfers),
        [(0, 0), (0, 50), (0, 0)],
      );
    });

    test('a transfer cannot go to the same wallet', () async {
      expect(
        () => db.insertTransfer(
          Transfer(
            fromWalletId: cash,
            toWalletId: cash,
            amount: 1,
            date: DateTime(2025),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('only unused wallets can be deleted, never the last one', () async {
      final state = AppState(db);
      await state.load();
      final bankWallet = state.walletById(bank)!;
      await db.insertRecurringRule(
        RecurringRule(
          title: 'x',
          amount: 1,
          categoryId: market.id!,
          startDate: DateTime(2100),
          walletId: bank,
        ),
      );
      expect(await state.deleteWallet(bankWallet), isFalse);
      await db.db.delete('recurring_rules');
      expect(await state.deleteWallet(bankWallet), isTrue);
      expect(state.wallets, hasLength(1));
      expect(await state.deleteWallet(state.wallets.single), isFalse);
    });

    test('switching a record to a transfer replaces it', () async {
      final state = AppState(db);
      await state.load();
      await state.setMonth(DateTime(2025, 1));
      final id = await db.insertRecord(
        Record(
          title: '',
          amount: 700,
          date: DateTime(2025, 1, 2),
          categoryId: market.id!,
          walletId: cash,
        ),
      );
      final record = (await db.records()).firstWhere((r) => r.id == id);
      await state.replaceEntry(
        oldRecord: record,
        newTransfer: Transfer(
          fromWalletId: cash,
          toWalletId: bank,
          amount: 700,
          date: record.date,
        ),
      );
      expect(state.monthRecords, isEmpty);
      expect(state.monthTransfers.single.amount, 700);
      expect(state.balances[bank], 1700);
    });
  });

  group('Oinkoin wallets and transfers', () {
    final backup = jsonEncode({
      'categories': [
        {'name': 'Market', 'category_type': 0},
      ],
      'wallets': [
        {'id': 7, 'name': 'Main', 'initial_amount': 100.5, 'is_archived': 0},
        {'id': 8, 'name': 'Savings', 'initial_amount': 0},
      ],
      'records': [
        {
          'title': 'Bread',
          'value': -2.5,
          'datetime': DateTime(2025, 3, 1).millisecondsSinceEpoch,
          'category_name': 'Market',
          'category_type': 0,
          'wallet_id': 8,
        },
        {
          // Transfer: no category; wallet_id is the source.
          'title': 'Saving',
          'value': -40.0,
          'transfer_value': 40.0,
          'datetime': DateTime(2025, 3, 2).millisecondsSinceEpoch,
          'wallet_id': 7,
          'transfer_wallet_id': 8,
        },
        {
          // Old backups have no wallet: goes to the default wallet.
          'title': 'Milk',
          'value': -1.0,
          'datetime': DateTime(2025, 3, 3).millisecondsSinceEpoch,
          'category_name': 'Market',
          'category_type': 0,
        },
      ],
    });

    test('are imported once and mapped to local wallets', () async {
      final db = await openMemory();
      final s = await importOinkoinBackup(db, parseOinkoinBackup(backup));
      expect(s.walletsAdded, 2);
      expect(s.transfersAdded, 1);
      expect(s.recordsAdded, 2);

      final wallets = {for (final w in await db.wallets()) w.name: w.id!};
      expect(wallets.keys, containsAll(['Nakit', 'Main', 'Savings']));
      final records = await db.records();
      expect(
        records.firstWhere((r) => r.title == 'Bread').walletId,
        wallets['Savings'],
      );
      expect(
        records.firstWhere((r) => r.title == 'Milk').walletId,
        wallets['Nakit'],
      );
      final t = (await db.transfers()).single;
      expect(
        (t.fromWalletId, t.toWalletId, t.amount, t.note),
        (wallets['Main'], wallets['Savings'], 4000, 'Saving'),
      );
      final b = await db.walletBalances();
      expect(b[wallets['Main']], 10050 - 4000);
      expect(b[wallets['Savings']], 4000 - 250);

      final again = await importOinkoinBackup(db, parseOinkoinBackup(backup));
      expect(
        (again.walletsAdded, again.transfersAdded, again.recordsAdded),
        (0, 0, 0),
      );
      expect(again.recordsSkipped, 3);
      await db.close();
    });
  });
}
