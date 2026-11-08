import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import 'backup.dart';

/// How often an automatic backup is taken. Stored by name in settings.
enum AutoBackupFrequency { off, daily, weekly, monthly }

/// Settings keys; these belong to the device and are not backed up.
const autoBackupKey = 'auto_backup';
const autoBackupLastKey = 'auto_backup_last';

/// Automatic backups kept on the device; older ones are deleted.
const autoBackupKeep = 5;

AutoBackupFrequency parseFrequency(String? name) =>
    AutoBackupFrequency.values.where((f) => f.name == name).firstOrNull ??
    AutoBackupFrequency.off;

/// Whether a backup is due at [now], given the last one at [last].
bool autoBackupDue(
  AutoBackupFrequency frequency,
  DateTime? last,
  DateTime now,
) {
  if (frequency == AutoBackupFrequency.off) return false;
  if (last == null) return true;
  final next = switch (frequency) {
    AutoBackupFrequency.daily => DateTime(last.year, last.month, last.day + 1),
    AutoBackupFrequency.weekly => DateTime(last.year, last.month, last.day + 7),
    AutoBackupFrequency.monthly => DateTime(
      last.year,
      last.month + 1,
      last.day,
    ),
    AutoBackupFrequency.off => throw StateError('unreachable'),
  };
  return !now.isBefore(next);
}

/// Writes a backup file somewhere on the device; returns where, for display.
abstract interface class BackupWriter {
  Future<String> save(String name, Uint8List bytes, {required int keep});
}

/// Android: Download/YASBA (or the app's own folder before Android 10).
class PlatformBackupWriter implements BackupWriter {
  const PlatformBackupWriter();
  static const _channel = MethodChannel('yasba/auto_backup');

  @override
  Future<String> save(String name, Uint8List bytes, {required int keep}) async {
    final where = await _channel.invokeMethod<String>('save', {
      'name': name,
      'bytes': bytes,
      'keep': keep,
    });
    return where ?? name;
  }
}

/// Takes a backup with [writer] if one is due, and records when.
/// Returns where it was written, or null if none was due.
Future<String?> runAutoBackupIfDue(
  AppDatabase db,
  BackupWriter writer,
  DateTime now, {
  required String appVersion,
  bool force = false,
}) async {
  final frequency = parseFrequency(await db.getSetting(autoBackupKey));
  final last = DateTime.tryParse(await db.getSetting(autoBackupLastKey) ?? '');
  if (frequency == AutoBackupFrequency.off) return null;
  if (!force && !autoBackupDue(frequency, last, now)) return null;
  final text = await exportBackup(db, appVersion: appVersion);
  final name =
      'yasba-auto-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.json';
  final where = await writer.save(
    name,
    Uint8List.fromList(utf8.encode(text)),
    keep: autoBackupKeep,
  );
  await db.setSetting(autoBackupLastKey, now.toIso8601String());
  return where;
}
