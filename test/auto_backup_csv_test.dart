import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/models/category.dart';
import 'package:yasba/models/debt.dart';
import 'package:yasba/models/record.dart';
import 'package:yasba/models/transfer.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/services/auto_backup.dart';
import 'package:yasba/services/backup.dart';
import 'package:yasba/services/csv_export.dart';
import 'package:yasba/state/app_state.dart';

/// Keeps written backups in memory.
class FakeWriter implements BackupWriter {
  final saved = <String, String>{};
  Object? error;

  @override
  Future<String> save(String name, Uint8List bytes, {required int keep}) async {
    if (error != null) throw error!;
    saved[name] = utf8.decode(bytes);
    return 'Documents/YASBA/$name';
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<AppDatabase> openDb() => AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );

  group('automatic backup', () {
    test('is due after the chosen period', () {
      final last = DateTime(2025, 1, 31, 10);
      bool due(AutoBackupFrequency f, DateTime now) =>
          autoBackupDue(f, last, now);
      expect(due(AutoBackupFrequency.off, DateTime(2030)), isFalse);
      expect(autoBackupDue(AutoBackupFrequency.weekly, null, last), isTrue);

      expect(
        due(AutoBackupFrequency.daily, DateTime(2025, 1, 31, 23)),
        isFalse,
      );
      expect(due(AutoBackupFrequency.daily, DateTime(2025, 2, 1)), isTrue);
      expect(due(AutoBackupFrequency.weekly, DateTime(2025, 2, 6)), isFalse);
      expect(due(AutoBackupFrequency.weekly, DateTime(2025, 2, 7)), isTrue);
      expect(due(AutoBackupFrequency.monthly, DateTime(2025, 2, 28)), isFalse);
      expect(due(AutoBackupFrequency.monthly, DateTime(2025, 3, 3)), isTrue);
    });

    test('is off by default and runs once per period when on', () async {
      final db = await openDb();
      final writer = FakeWriter();
      var now = DateTime(2025, 3, 1, 9);
      final state = AppState(db, clock: () => now, backupWriter: writer);
      await state.load();
      expect(state.autoBackup, AutoBackupFrequency.off);
      expect(writer.saved, isEmpty);

      // Turning it on backs up right away.
      await state.setAutoBackup(AutoBackupFrequency.weekly);
      expect(writer.saved, hasLength(1));
      expect(state.lastAutoBackup, now);
      expect(state.autoBackupLocation, 'Documents/YASBA');
      final backup = parseBackup(writer.saved.values.single);
      expect(backup.count('wallets'), 1);
      // Automatic backup settings belong to the device, not the backup.
      expect(
        backup.tables['settings']!.map((r) => r['key']),
        isNot(contains(autoBackupKey)),
      );

      now = DateTime(2025, 3, 5);
      await state.autoBackupIfDue();
      expect(writer.saved, hasLength(1));
      now = DateTime(2025, 3, 8, 9);
      await state.autoBackupIfDue();
      expect(writer.saved, hasLength(2));

      // The setting survives a restart.
      final again = AppState(db, clock: () => now, backupWriter: writer);
      await again.load();
      expect(again.autoBackup, AutoBackupFrequency.weekly);
      expect(again.lastAutoBackup, now);
      await db.close();
    });

    test('a failure is reported, not thrown', () async {
      final db = await openDb();
      final writer = FakeWriter()..error = Exception('disk full');
      final state = AppState(db, backupWriter: writer);
      await state.load();
      await state.setAutoBackup(AutoBackupFrequency.daily);
      expect(state.autoBackupError, contains('disk full'));
      expect(state.lastAutoBackup, isNull);
      await db.close();
    });
  });

  test('CSV export', () {
    const market = Category(
      id: 1,
      name: 'Market',
      type: CategoryType.expense,
      color: 0,
    );
    const salary = Category(
      id: 2,
      name: 'Maaş',
      type: CategoryType.income,
      color: 0,
    );
    const cash = Wallet(id: 1, name: 'Nakit', color: 0);
    const bank = Wallet(id: 2, name: 'Banka', color: 0);
    final csv = exportCsv(
      records: [
        Record(
          title: 'Migros, "büyük"',
          amount: 84250,
          date: DateTime(2025, 3, 2, 18, 5),
          categoryId: 1,
          note: 'iki\nsatır',
          walletId: 1,
        ),
        Record(
          title: '',
          amount: 4500000,
          date: DateTime(2025, 3, 1, 9),
          categoryId: 2,
          walletId: 2,
        ),
      ],
      transfers: [
        Transfer(
          fromWalletId: 2,
          toWalletId: 1,
          amount: 200000,
          date: DateTime(2025, 3, 3),
        ),
      ],
      debtEvents: () {
        final debt = Debt(
          person: 'Ali',
          direction: DebtDirection.lent,
          amount: 30000,
          date: DateTime(2025, 3, 4),
          walletId: 2,
          note: 'kira',
        );
        return [
          DebtEvent(debt, null),
          DebtEvent(
            debt,
            DebtPayment(debtId: 1, amount: 10000, date: DateTime(2025, 3, 5)),
          ),
        ];
      }(),
      categories: {1: market, 2: salary},
      wallets: {1: cash, 2: bank},
      currency: '₺',
      labels: const CsvLabels(
        headers: [
          'Tarih',
          'Tür',
          'Kategori',
          'Cüzdan',
          'Hedef',
          'Başlık',
          'Not',
          'Tutar',
          'Para birimi',
        ],
        income: 'Gelir',
        expense: 'Gider',
        transfer: 'Aktarım',
        debtLent: 'Borç verildi',
        debtBorrowed: 'Borç alındı',
        repaymentReceived: 'Ödeme alındı',
        repaymentMade: 'Ödeme yapıldı',
      ),
    );
    expect(csv, startsWith('﻿'));
    expect(csv.substring(1).split('\n'), [
      'Tarih,Tür,Kategori,Cüzdan,Hedef,Başlık,Not,Tutar,Para birimi',
      '2025-03-01 09:00,Gelir,Maaş,Banka,,,,45000.00,₺',
      '2025-03-02 18:05,Gider,Market,Nakit,,"Migros, ""büyük""","iki',
      'satır",-842.50,₺',
      '2025-03-03 00:00,Aktarım,,Banka,Nakit,,,2000.00,₺',
      '2025-03-04 00:00,Borç verildi,,Banka,,Ali,kira,-300.00,₺',
      '2025-03-05 00:00,Ödeme alındı,,,,Ali,,100.00,₺',
      '',
    ]);
  });
}
