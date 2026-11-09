import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/backup.dart';
import '../state/app_state.dart';
import 'widgets/dialogs.dart';

/// Picks a YASBA backup file, shows what is in it and, once confirmed,
/// replaces all data with it. Returns whether data was restored.
Future<bool> restoreBackupFromFile(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final file = await FilePicker.pickFile(
    dialogTitle: l.backupPick,
    type: FileType.any,
  );
  if (file == null || !context.mounted) return false;

  final YasbaBackup backup;
  try {
    backup = parseBackup(utf8.decode(await file.readAsBytes()));
  } on BackupException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (e.error) {
          BackupError.notJson || BackupError.notBackup => l.backupNotBackup,
          BackupError.newerVersion => l.backupNewer,
        }),
      ),
    );
    return false;
  } on FormatException {
    messenger.showSnackBar(SnackBar(content: Text(l.importNotUtf8)));
    return false;
  }
  if (!context.mounted) return false;

  final date = backup.createdAt == null
      ? l.unknownDate
      : DateFormat.yMMMd().add_Hm().format(backup.createdAt!.toLocal());
  final ok = await confirm(
    context,
    title: l.backupRestoreQuestion,
    message: l.backupRestoreDetails(
      date,
      backup.count('wallets'),
      backup.count('records'),
      backup.count('transfers'),
      backup.count('recurring_rules'),
    ),
    action: l.backupRestoreConfirm,
  );
  if (!ok || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  String message;
  var restored = false;
  try {
    await state.restoreFromBackup(backup);
    message = l.backupRestored;
    restored = true;
  } catch (e) {
    message = l.importFailed('$e');
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  messenger.showSnackBar(SnackBar(content: Text(message)));
  return restored;
}
