import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/models/record.dart';
import 'package:yasba/models/recurring_rule.dart';
import 'package:yasba/models/transfer.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/services/backup.dart';
import 'package:yasba/services/recurring_service.dart';

const _tables = [
  'wallets',
  'categories',
  'recurring_rules',
  'records',
  'transfers',
];

void main() {
  late Directory dir;

  setUpAll(sqfliteFfiInit);
  setUp(() async => dir = await Directory.systemTemp.createTemp('yasba'));
  tearDown(() => dir.delete(recursive: true));

  Future<AppDatabase> open(String name, {String language = 'en'}) =>
      AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${dir.path}/$name.db',
        language: language,
      );

  /// A database with some of everything.
  Future<AppDatabase> filled() async {
    final db = await open('source', language: 'tr');
    final cash = (await db.wallets()).single.id!;
    final bank = await db.insertWallet(
      const Wallet(name: 'Banka', color: 0xFF1E88E5, initialBalance: 50000),
    );
    final cats = {for (final c in await db.categories()) c.name: c.id!};
    final rule = await db.insertRecurringRule(
      RecurringRule(
        title: 'Kira',
        amount: 1800000,
        categoryId: cats['Kira']!,
        startDate: DateTime(2025, 1, 1),
        walletId: bank,
      ),
    );
    await generateDueRecurringRecords(db, DateTime(2025, 3, 15));
    await db.insertRecord(
      Record(
        title: 'Migros',
        amount: 84250,
        date: DateTime(2025, 3, 2),
        categoryId: cats['Market']!,
        note: 'not',
        walletId: cash,
      ),
    );
    await db.insertTransfer(
      Transfer(
        fromWalletId: bank,
        toWalletId: cash,
        amount: 200000,
        date: DateTime(2025, 3, 3),
        note: 'ATM',
      ),
    );
    await db.setSetting('currency', '€');
    await db.setSetting('language', 'tr');
    expect(rule, isPositive);
    return db;
  }

  Future<Map<String, List<Map<String, Object?>>>> dump(AppDatabase db) async =>
      {for (final t in _tables) t: await db.db.query(t, orderBy: 'id')};

  test('backup and restore round trip', () async {
    final source = await filled();
    final text = await exportBackup(source, appVersion: '1.2.3');
    final json = jsonDecode(text) as Map;
    expect(json['format'], 'yasba-backup');
    expect(json['app_version'], '1.2.3');

    // Restore into a database that already has other data.
    final target = await open('target');
    await target.insertWallet(const Wallet(name: 'Old', color: 0xFF000000));
    await target.setSetting('language', 'en');
    final backup = parseBackup(text);
    expect(backup.count('records'), 4); // 3 rent + 1 market
    expect(backup.count('transfers'), 1);
    await restoreBackup(target, backup);

    expect(await dump(target), await dump(source));
    expect(await target.walletBalances(), await source.walletBalances());
    expect(await target.getSetting('currency'), '€');
    // The UI language belongs to the device, not the backup.
    expect(await target.getSetting('language'), 'en');
    // Recurring rules continue where they were: nothing is re-created.
    expect(await generateDueRecurringRecords(target, DateTime(2025, 3, 20)), 0);
    expect(await generateDueRecurringRecords(target, DateTime(2025, 4, 1)), 1);

    await source.close();
    await target.close();
  });

  test('invalid files are rejected and change nothing', () async {
    final db = await open('db');
    final before = await dump(db);
    BackupError errorOf(String text) {
      try {
        parseBackup(text);
      } on BackupException catch (e) {
        return e.error;
      }
      fail('no error for $text');
    }

    expect(errorOf('not json'), BackupError.notJson);
    expect(errorOf('{"categories": []}'), BackupError.notBackup);
    expect(
      errorOf('{"format": "yasba-backup", "version": 1, "tables": {}}'),
      BackupError.notBackup,
    );
    final good = jsonDecode(await exportBackup(db, appVersion: 'dev')) as Map;
    expect(
      errorOf(jsonEncode({...good, 'version': backupVersion + 1})),
      BackupError.newerVersion,
    );
    expect(await dump(db), before);
    await db.close();
  });

  test('a failed restore leaves the data untouched', () async {
    final db = await open('db');
    final before = await dump(db);
    final good = jsonDecode(await exportBackup(db, appVersion: 'dev')) as Map;
    final tables = Map<String, Object?>.from(good['tables'] as Map);
    // A record pointing to a category that does not exist.
    tables['records'] = [
      {
        'id': 1,
        'title': 'x',
        'amount': 1,
        'date': 0,
        'category_id': 999,
        'wallet_id': 1,
      },
    ];
    final broken = parseBackup(jsonEncode({...good, 'tables': tables}));
    await expectLater(restoreBackup(db, broken), throwsA(anything));
    expect(await dump(db), before);
    await db.close();
  });
}
