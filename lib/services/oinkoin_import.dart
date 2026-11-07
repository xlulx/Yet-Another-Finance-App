import 'dart:convert';

import '../data/app_database.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';

/// Data read from an Oinkoin backup (not yet written to the database).
///
/// Categories are matched by `(name, type)`, the same way Oinkoin does.
class OinkoinBackup {
  OinkoinBackup(this.categories, this.records, this.rules);

  final List<Category> categories;

  /// Category key + record. [Record.categoryId] is meaningless here.
  final List<(CategoryKey, Record, String? patternId)> records;
  final List<(CategoryKey, RecurringRule, String? patternId)> rules;
}

typedef CategoryKey = (String name, CategoryType type);

class OinkoinImportException implements Exception {
  OinkoinImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportSummary {
  const ImportSummary({
    required this.categoriesAdded,
    required this.recordsAdded,
    required this.recordsSkipped,
    required this.rulesAdded,
  });
  final int categoriesAdded;
  final int recordsAdded;
  final int recordsSkipped;
  final int rulesAdded;
}

/// Parses an Oinkoin `.json` backup file.
OinkoinBackup parseOinkoinBackup(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw OinkoinImportException('Dosya geçerli bir JSON değil.');
  }
  if (decoded is! Map || decoded['categories'] is! List) {
    throw OinkoinImportException(
      'Bu dosya bir Oinkoin yedeği gibi görünmüyor.',
    );
  }

  final categories = <CategoryKey, Category>{};
  var order = 0;
  for (final raw in decoded['categories'] as List) {
    if (raw is! Map || raw['name'] == null) continue;
    final type = _type(raw['category_type']);
    final name = raw['name'].toString().trim();
    if (name.isEmpty) continue;
    categories[(name, type)] = Category(
      name: name,
      type: type,
      color: _color(raw['color'], type),
      icon: 'category',
      emoji: _nonEmpty(raw['icon_emoji']),
      archived: raw['is_archived'] == 1 || raw['is_archived'] == true,
      sortOrder: (raw['sort_order'] as num?)?.toInt() ?? order,
    );
    order++;
  }

  CategoryKey? keyOf(Map raw) {
    final name = raw['category_name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    final key = (name, _type(raw['category_type']));
    // Create the category if a record references one missing from the backup.
    categories.putIfAbsent(
      key,
      () => Category(
        name: key.$1,
        type: key.$2,
        color: _color(null, key.$2),
        sortOrder: order++,
      ),
    );
    return key;
  }

  final records = <(CategoryKey, Record, String?)>[];
  for (final raw in decoded['records'] as List? ?? const []) {
    if (raw is! Map) continue;
    final key = keyOf(raw);
    final millis = (raw['datetime'] as num?)?.toInt();
    final value = (raw['value'] as num?)?.toDouble();
    // Note: transfers (between wallets) have no category and are skipped.
    if (key == null || millis == null || value == null) continue;
    records.add((
      key,
      Record(
        title: raw['title']?.toString() ?? '',
        amount: _cents(value),
        date: DateTime.fromMillisecondsSinceEpoch(millis),
        categoryId: 0,
        note: _nonEmpty(raw['description']),
      ),
      raw['recurrence_id']?.toString(),
    ));
  }

  final rules = <(CategoryKey, RecurringRule, String?)>[];
  for (final raw in decoded['recurrent_record_patterns'] as List? ?? const []) {
    if (raw is! Map) continue;
    final key = keyOf(raw);
    final millis = (raw['datetime'] as num?)?.toInt();
    final value = (raw['value'] as num?)?.toDouble();
    final period = _period(raw);
    if (key == null || millis == null || value == null || period == null) {
      continue;
    }
    DateTime? ms(Object? v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    rules.add((
      key,
      RecurringRule(
        title: raw['title']?.toString() ?? '',
        amount: _cents(value),
        categoryId: 0,
        note: _nonEmpty(raw['description']),
        startDate: DateTime.fromMillisecondsSinceEpoch(millis),
        interval: period.$1,
        unit: period.$2,
        endDate: ms(raw['end_date']),
        lastGenerated: ms(raw['last_update']),
      ),
      raw['id']?.toString(),
    ));
  }

  return OinkoinBackup(categories.values.toList(), records, rules);
}

/// Writes a parsed backup to the database. Categories with the same
/// name/type are merged and identical records (date, amount, title,
/// category) are skipped, so importing the same backup twice is safe.
Future<ImportSummary> importOinkoinBackup(
  AppDatabase db,
  OinkoinBackup backup,
) {
  return db.db.transaction((txn) async {
    final ids = <CategoryKey, int>{
      for (final c in await db.categories(txn: txn)) (c.name, c.type): c.id!,
    };
    var categoriesAdded = 0;
    for (final c in backup.categories) {
      final key = (c.name, c.type);
      if (ids.containsKey(key)) continue;
      ids[key] = await db.insertCategory(c, txn: txn);
      categoriesAdded++;
    }

    final ruleIds = <String, int>{};
    final existingRules = {
      for (final r in await db.recurringRules(txn: txn))
        (r.title, r.amount, r.categoryId, r.startDate.millisecondsSinceEpoch),
    };
    var rulesAdded = 0;
    for (final (key, rule, patternId) in backup.rules) {
      final r = rule.copyWith(categoryId: ids[key]);
      final sig = (
        r.title,
        r.amount,
        r.categoryId,
        r.startDate.millisecondsSinceEpoch,
      );
      if (existingRules.contains(sig)) continue;
      final id = await db.insertRecurringRule(r, txn: txn);
      existingRules.add(sig);
      if (patternId != null) ruleIds[patternId] = id;
      rulesAdded++;
    }

    final existing = {
      for (final row in await txn.query(
        'records',
        columns: ['title', 'amount', 'date', 'category_id'],
      ))
        (row['title'], row['amount'], row['date'], row['category_id']),
    };
    var added = 0, skipped = 0;
    for (final (key, record, patternId) in backup.records) {
      final r = Record(
        title: record.title,
        amount: record.amount,
        date: record.date,
        categoryId: ids[key]!,
        note: record.note,
        recurringId: patternId == null ? null : ruleIds[patternId],
      );
      final sig = (
        r.title,
        r.amount,
        r.date.millisecondsSinceEpoch,
        r.categoryId,
      );
      if (!existing.add(sig)) {
        skipped++;
        continue;
      }
      await db.insertRecord(r, txn: txn);
      added++;
    }

    return ImportSummary(
      categoriesAdded: categoriesAdded,
      recordsAdded: added,
      recordsSkipped: skipped,
      rulesAdded: rulesAdded,
    );
  });
}

CategoryType _type(Object? v) =>
    v == 1 ? CategoryType.income : CategoryType.expense;

/// Oinkoin stores amounts as doubles, negative for expenses.
int _cents(double v) => (v.abs() * 100).round();

String? _nonEmpty(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Oinkoin stores colours as `"a:r:g:b"`.
int _color(Object? v, CategoryType type) {
  if (v is String) {
    final parts = v.split(':').map(int.tryParse).toList();
    if (parts.length == 4 && parts.every((p) => p != null)) {
      final [a, r, g, b] = parts.cast<int>();
      return (a & 0xFF) << 24 | (r & 0xFF) << 16 | (g & 0xFF) << 8 | (b & 0xFF);
    }
  }
  return type == CategoryType.income ? 0xFF66BB6A : 0xFF90A4AE;
}

/// Maps an Oinkoin `RecurrentPeriod` index to an (interval, unit) pair.
(int, RecurrenceUnit)? _period(Map raw) {
  switch (raw['recurrent_period']) {
    case 0:
      return (1, RecurrenceUnit.day);
    case 1:
      return (1, RecurrenceUnit.week);
    case 2:
      return (1, RecurrenceUnit.month);
    case 3:
      return (2, RecurrenceUnit.week);
    case 4:
      return (3, RecurrenceUnit.month);
    case 5:
      return (4, RecurrenceUnit.month);
    case 6:
      return (1, RecurrenceUnit.year);
    case 7:
      return (4, RecurrenceUnit.week);
    case 8:
      final value = (raw['custom_interval_value'] as num?)?.toInt();
      final unit = (raw['custom_interval_unit'] as num?)?.toInt();
      if (value == null || value < 1 || unit == null) return null;
      if (unit < 0 || unit >= RecurrenceUnit.values.length) return null;
      return (value, RecurrenceUnit.values[unit]);
  }
  return null;
}
