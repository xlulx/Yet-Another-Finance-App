import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

/// YASBA's own backup: every table as plain rows in one JSON file.
///
/// ```json
/// {"format": "yasba-backup", "version": 1, "created_at": "...",
///  "app_version": "0.4.0", "tables": {"wallets": [...], ...}}
/// ```
const backupFormat = 'yasba-backup';

/// Backups made before the app was renamed from YAFA (v0.4.0); still
/// accepted so data can be moved to the renamed app.
const _oldBackupFormats = {'yafa-backup'};

/// Bump when the file layout changes in a way older apps cannot read.
const backupVersion = 1;

/// Tables in insert order (parents before children). Settings that only
/// make sense on one device (UI language, automatic backups) are not backed
/// up.
const _tables = [
  'wallets',
  'categories',
  'recurring_rules',
  'records',
  'transfers',
  'settings',
];
const _deviceSettings = {'language', 'auto_backup', 'auto_backup_last'};

enum BackupError { notJson, notBackup, newerVersion }

class BackupException implements Exception {
  BackupException(this.error);
  final BackupError error;
  @override
  String toString() => 'BackupException(${error.name})';
}

/// A parsed backup, checked but not yet restored.
class YasbaBackup {
  YasbaBackup(this.createdAt, this.tables);

  final DateTime? createdAt;
  final Map<String, List<Map<String, Object?>>> tables;

  int count(String table) => tables[table]?.length ?? 0;
}

/// Reads the whole database into a backup file's text.
Future<String> exportBackup(
  AppDatabase db, {
  required String appVersion,
}) async {
  final tables = <String, Object?>{};
  for (final t in _tables) {
    var rows = await db.db.query(t);
    if (t == 'settings') {
      rows = rows.where((r) => !_deviceSettings.contains(r['key'])).toList();
    }
    tables[t] = rows;
  }
  return jsonEncode({
    'format': backupFormat,
    'version': backupVersion,
    'created_at': DateTime.now().toIso8601String(),
    'app_version': appVersion,
    'tables': tables,
  });
}

/// Parses and checks a backup file's text. Throws [BackupException].
YasbaBackup parseBackup(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw BackupException(BackupError.notJson);
  }
  if (decoded is! Map ||
      !{backupFormat, ..._oldBackupFormats}.contains(decoded['format']) ||
      decoded['tables'] is! Map) {
    throw BackupException(BackupError.notBackup);
  }
  final version = decoded['version'];
  if (version is! int) throw BackupException(BackupError.notBackup);
  if (version > backupVersion) throw BackupException(BackupError.newerVersion);

  final raw = decoded['tables'] as Map;
  final tables = <String, List<Map<String, Object?>>>{};
  for (final t in _tables) {
    final rows = raw[t] ?? const [];
    if (rows is! List || rows.any((r) => r is! Map)) {
      throw BackupException(BackupError.notBackup);
    }
    tables[t] = [for (final r in rows) Map<String, Object?>.from(r as Map)];
  }
  // Every record needs a wallet: a backup without one is not ours.
  if (tables['wallets']!.isEmpty) throw BackupException(BackupError.notBackup);
  return YasbaBackup(
    DateTime.tryParse(decoded['created_at']?.toString() ?? ''),
    tables,
  );
}

/// Replaces all data with the backup's, in one transaction: on any error
/// nothing changes. Unknown columns (from newer files) are ignored.
Future<void> restoreBackup(AppDatabase db, YasbaBackup backup) {
  return db.db.transaction((txn) async {
    // Rows reference each other; check foreign keys at commit instead.
    await txn.execute('PRAGMA defer_foreign_keys = ON');
    for (final t in _tables.reversed) {
      if (t == 'settings') {
        await txn.delete(
          t,
          where:
              'key NOT IN (${List.filled(_deviceSettings.length, '?').join(',')})',
          whereArgs: _deviceSettings.toList(),
        );
      } else {
        await txn.delete(t);
      }
    }
    for (final t in _tables) {
      final columns = {
        for (final c in await txn.rawQuery('PRAGMA table_info($t)'))
          c['name'] as String,
      };
      for (final row in backup.tables[t]!) {
        if (t == 'settings' && _deviceSettings.contains(row['key'])) continue;
        await txn.insert(t, {
          for (final e in row.entries)
            if (columns.contains(e.key)) e.key: e.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  });
}
