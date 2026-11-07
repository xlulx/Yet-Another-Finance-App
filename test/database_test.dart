import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yafa/data/app_database.dart';
import 'package:yafa/models/category.dart';
import 'package:yafa/models/recurring_rule.dart';
import 'package:yafa/services/oinkoin_import.dart';
import 'package:yafa/services/recurring_service.dart';
import 'package:yafa/services/stats.dart';

/// Oinkoin'in yedek biçimini taklit eden küçük örnek.
final _backup = jsonEncode({
  'package_name': 'com.github.emavgl.piggybankpro',
  'version': '1.0',
  'database_version': '16',
  'created_at': 0,
  'categories': [
    {
      'name': 'Market',
      'category_type': 0,
      'color': '255:102:187:106',
      'icon': 12345,
      'is_archived': 0,
      'sort_order': 0,
    },
    {
      'name': 'Kahve',
      'category_type': 0,
      'color': '255:255:0:0',
      'icon_emoji': '☕',
      'sort_order': 1,
    },
    {'name': 'Maaş', 'category_type': 1, 'color': null, 'sort_order': 0},
  ],
  'records': [
    {
      'id': 1,
      'title': 'Haftalık alışveriş',
      'value': -123.45,
      'datetime': DateTime(2025, 3, 5, 12).millisecondsSinceEpoch,
      'category_name': 'Market',
      'category_type': 0,
      'description': 'not',
    },
    {
      'id': 2,
      'title': null,
      'value': -3.5,
      'datetime': DateTime(2025, 3, 6, 9).millisecondsSinceEpoch,
      'category_name': 'Kahve',
      'category_type': 0,
    },
    {
      'id': 3,
      'title': 'Mart maaşı',
      'value': 50000.0,
      'datetime': DateTime(2025, 3, 1, 9).millisecondsSinceEpoch,
      'category_name': 'Maaş',
      'category_type': 1,
      'recurrence_id': 'abc',
    },
    // Transfer: kategorisiz, atlanmalı.
    {
      'id': 4,
      'value': -10.0,
      'datetime': DateTime(2025, 3, 2).millisecondsSinceEpoch,
      'transfer_wallet_id': 2,
    },
  ],
  'recurrent_record_patterns': [
    {
      'id': 'abc',
      'title': 'Mart maaşı',
      'value': 50000.0,
      'datetime': DateTime(2025, 3, 1, 9).millisecondsSinceEpoch,
      'category_name': 'Maaş',
      'category_type': 1,
      'recurrent_period': 2,
      'last_update': DateTime(2025, 3, 1, 9).millisecondsSinceEpoch,
    },
    {
      'id': 'def',
      'title': 'Özel',
      'value': -10.0,
      'datetime': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'category_name': 'Market',
      'category_type': 0,
      'recurrent_period': 8,
      'custom_interval_value': 6,
      'custom_interval_unit': 2,
    },
  ],
});

void main() {
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => db.close());

  test('varsayılan kategoriler oluşturulur', () async {
    final cats = await db.categories();
    expect(cats.where((c) => c.type == CategoryType.expense), isNotEmpty);
    expect(cats.where((c) => c.type == CategoryType.income), isNotEmpty);
  });

  group('Oinkoin içe aktarma', () {
    test('ayrıştırma', () {
      final b = parseOinkoinBackup(_backup);
      expect(b.categories, hasLength(3));
      final kahve = b.categories.firstWhere((c) => c.name == 'Kahve');
      expect(kahve.emoji, '☕');
      expect(kahve.color, 0xFFFF0000);
      expect(b.records, hasLength(3)); // transfer atlandı
      expect(b.records.first.$2.amount, 12345);
      expect(b.rules, hasLength(2));
      final custom = b.rules.firstWhere((r) => r.$2.title == 'Özel').$2;
      expect(custom.interval, 6);
      expect(custom.unit, RecurrenceUnit.month);
    });

    test('geçersiz dosya anlaşılır hata verir', () {
      expect(
        () => parseOinkoinBackup('nope'),
        throwsA(isA<OinkoinImportException>()),
      );
      expect(
        () => parseOinkoinBackup('{"foo": 1}'),
        throwsA(isA<OinkoinImportException>()),
      );
    });

    test('veritabanına yazma, birleştirme ve tekrar içe aktarma', () async {
      final before = (await db.categories()).length;
      final s1 = await importOinkoinBackup(db, parseOinkoinBackup(_backup));
      // "Market" ve "Maaş" varsayılanlarda var, sadece "Kahve" eklenir.
      expect(s1.categoriesAdded, 1);
      expect((await db.categories()).length, before + 1);
      expect(s1.recordsAdded, 3);
      expect(s1.rulesAdded, 2);

      final records = await db.records();
      final salary = records.firstWhere((r) => r.title == 'Mart maaşı');
      expect(salary.amount, 5000000);
      expect(salary.recurringId, isNotNull);

      final s2 = await importOinkoinBackup(db, parseOinkoinBackup(_backup));
      expect(s2.recordsAdded, 0);
      expect(s2.recordsSkipped, 3);
      expect(s2.rulesAdded, 0);
      expect(await db.records(), hasLength(3));
    });
  });

  test('tekrarlayan kayıtlar üretilir ve tekrar üretilmez', () async {
    final cat = (await db.categories()).first;
    await db.insertRecurringRule(
      RecurringRule(
        title: 'Kira',
        amount: 1000000,
        categoryId: cat.id!,
        startDate: DateTime(2025, 1, 1),
      ),
    );
    expect(await generateDueRecurringRecords(db, DateTime(2025, 3, 15)), 3);
    expect(await generateDueRecurringRecords(db, DateTime(2025, 3, 15)), 0);
    expect(await generateDueRecurringRecords(db, DateTime(2025, 4, 1)), 1);
    final records = await db.records();
    expect(records, hasLength(4));
    expect(records.every((r) => r.recurringId != null), isTrue);

    // Kural silinince kayıtlar kalır.
    await db.deleteRecurringRule((await db.recurringRules()).single.id!);
    final after = await db.records();
    expect(after, hasLength(4));
    expect(after.every((r) => r.recurringId == null), isTrue);
  });

  test('kategori silinince kayıtları da silinir; istatistik', () async {
    await importOinkoinBackup(db, parseOinkoinBackup(_backup));
    final cats = await db.categories();
    final byId = {for (final c in cats) c.id!: c};
    final records = await db.records(
      from: DateTime(2025, 3),
      to: DateTime(2025, 4),
    );
    final totals = totalsByCategory(records, byId, CategoryType.expense);
    expect(totals.map((t) => t.category.name), ['Market', 'Kahve']);
    expect(totals.first.total, 12345);

    final buckets = bucketTotals(records, byId, 31, (d) => d.day - 1);
    expect(buckets[0].$1, 5000000);
    expect(buckets[4].$2, 12345);

    await db.deleteCategory(cats.firstWhere((c) => c.name == 'Kahve').id!);
    expect(await db.records(), hasLength(2));
  });
}
