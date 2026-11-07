import 'dart:convert';

import '../data/app_database.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_rule.dart';
import '../models/transfer.dart';
import '../models/wallet.dart';

/// Data read from an Oinkoin backup (not yet written to the database).
///
/// Categories are matched by `(name, type)`, the same way Oinkoin does.
///
/// Wallet ids in [records], [rules] and [transfers] are Oinkoin's own ids
/// (keys of [wallets]); they are mapped to local ids on import.
class OinkoinBackup {
  OinkoinBackup(
    this.categories,
    this.records,
    this.rules, {
    this.wallets = const {},
    this.transfers = const [],
  });

  final List<Category> categories;

  /// Oinkoin wallet id -> wallet.
  final Map<int, Wallet> wallets;
  final List<Transfer> transfers;

  /// Category key + record. [Record.categoryId] is meaningless here.
  final List<(CategoryKey, Record, String? patternId)> records;
  final List<(CategoryKey, RecurringRule, String? patternId)> rules;
}

typedef CategoryKey = (String name, CategoryType type);

enum OinkoinImportError { notJson, notOinkoinBackup }

class OinkoinImportException implements Exception {
  OinkoinImportException(this.error);
  final OinkoinImportError error;
  @override
  String toString() => 'OinkoinImportException(${error.name})';
}

class ImportSummary {
  const ImportSummary({
    required this.categoriesAdded,
    required this.recordsAdded,
    required this.recordsSkipped,
    required this.rulesAdded,
    this.walletsAdded = 0,
    this.transfersAdded = 0,
  });
  final int walletsAdded;
  final int transfersAdded;
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
    throw OinkoinImportException(OinkoinImportError.notJson);
  }
  if (decoded is! Map || decoded['categories'] is! List) {
    throw OinkoinImportException(OinkoinImportError.notOinkoinBackup);
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

  final wallets = <int, Wallet>{};
  for (final raw in decoded['wallets'] as List? ?? const []) {
    if (raw is! Map) continue;
    final id = (raw['id'] as num?)?.toInt();
    final name = raw['name']?.toString().trim() ?? '';
    if (id == null || name.isEmpty) continue;
    wallets[id] = Wallet(
      name: name,
      color: _color(raw['color'], CategoryType.expense, fallback: 0xFF42A5F5),
      icon: 'bank',
      initialBalance: ((raw['initial_amount'] as num? ?? 0) * 100).round(),
      archived: raw['is_archived'] == 1 || raw['is_archived'] == true,
      sortOrder: (raw['sort_order'] as num?)?.toInt() ?? wallets.length,
    );
  }
  int? walletOf(Object? v) {
    final id = (v as num?)?.toInt();
    return wallets.containsKey(id) ? id : null;
  }

  final transfers = <Transfer>[];
  final records = <(CategoryKey, Record, String?)>[];
  for (final raw in decoded['records'] as List? ?? const []) {
    if (raw is! Map) continue;
    final millis = (raw['datetime'] as num?)?.toInt();
    final value = (raw['value'] as num?)?.toDouble();
    if (millis == null || value == null) continue;
    // Transfers have no category: the record's wallet is the source and
    // transfer_wallet_id the destination.
    if (raw['transfer_wallet_id'] != null) {
      final from = walletOf(raw['wallet_id']);
      final to = walletOf(raw['transfer_wallet_id']);
      if (from != null && to != null && from != to && value != 0) {
        transfers.add(
          Transfer(
            fromWalletId: from,
            toWalletId: to,
            amount: _cents(value),
            date: DateTime.fromMillisecondsSinceEpoch(millis),
            note: _nonEmpty(raw['title']) ?? _nonEmpty(raw['description']),
          ),
        );
      }
      continue;
    }
    final key = keyOf(raw);
    if (key == null) continue;
    records.add((
      key,
      Record(
        title: raw['title']?.toString() ?? '',
        amount: _cents(value),
        date: DateTime.fromMillisecondsSinceEpoch(millis),
        categoryId: 0,
        note: _nonEmpty(raw['description']),
        walletId: walletOf(raw['wallet_id']),
      ),
      raw['recurrence_id']?.toString(),
    ));
  }

  final rules = <(CategoryKey, RecurringRule, String?)>[];
  for (final raw in decoded['recurrent_record_patterns'] as List? ?? const []) {
    if (raw is! Map) continue;
    // Recurring transfers are not supported yet.
    if (raw['transfer_wallet_id'] != null) continue;
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
        walletId: walletOf(raw['wallet_id']),
      ),
      raw['id']?.toString(),
    ));
  }

  return OinkoinBackup(
    categories.values.toList(),
    records,
    rules,
    wallets: wallets,
    transfers: transfers,
  );
}

/// Writes a parsed backup to the database. Wallets with the same name and
/// categories with the same name/type are merged, and identical records and
/// transfers are skipped, so importing the same backup twice is safe.
/// Records without a known wallet go to the default wallet.
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

    final walletByName = {
      for (final w in await db.wallets(txn: txn)) w.name: w.id!,
    };
    final walletIds = <int, int>{}; // Oinkoin id -> local id
    var walletsAdded = 0;
    for (final MapEntry(key: oid, value: w) in backup.wallets.entries) {
      final existing = walletByName[w.name];
      if (existing != null) {
        walletIds[oid] = existing;
        continue;
      }
      final id = await db.insertWallet(w, txn: txn);
      walletByName[w.name] = walletIds[oid] = id;
      walletsAdded++;
    }

    final ruleIds = <String, int>{};
    final existingRules = {
      for (final r in await db.recurringRules(txn: txn))
        (r.title, r.amount, r.categoryId, r.startDate.millisecondsSinceEpoch),
    };
    var rulesAdded = 0;
    for (final (key, rule, patternId) in backup.rules) {
      final r = RecurringRule(
        title: rule.title,
        amount: rule.amount,
        categoryId: ids[key]!,
        note: rule.note,
        startDate: rule.startDate,
        interval: rule.interval,
        unit: rule.unit,
        endDate: rule.endDate,
        lastGenerated: rule.lastGenerated,
        walletId: walletIds[rule.walletId],
      );
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
        walletId: walletIds[record.walletId],
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

    final existingTransfers = {
      for (final t in await txn.query('transfers'))
        (t['from_wallet_id'], t['to_wallet_id'], t['amount'], t['date']),
    };
    var transfersAdded = 0;
    for (final t in backup.transfers) {
      final from = walletIds[t.fromWalletId]!;
      final to = walletIds[t.toWalletId]!;
      if (from == to) continue;
      final sig = (from, to, t.amount, t.date.millisecondsSinceEpoch);
      if (!existingTransfers.add(sig)) {
        skipped++;
        continue;
      }
      await db.insertTransfer(
        Transfer(
          fromWalletId: from,
          toWalletId: to,
          amount: t.amount,
          date: t.date,
          note: t.note,
        ),
        txn: txn,
      );
      transfersAdded++;
    }

    return ImportSummary(
      walletsAdded: walletsAdded,
      transfersAdded: transfersAdded,
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
int _color(Object? v, CategoryType type, {int? fallback}) {
  if (v is String) {
    final parts = v.split(':').map(int.tryParse).toList();
    if (parts.length == 4 && parts.every((p) => p != null)) {
      final [a, r, g, b] = parts.cast<int>();
      return (a & 0xFF) << 24 | (r & 0xFF) << 16 | (g & 0xFF) << 8 | (b & 0xFF);
    }
  }
  return fallback ?? (type == CategoryType.income ? 0xFF66BB6A : 0xFF90A4AE);
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
