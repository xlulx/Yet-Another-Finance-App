import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Uint8List;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../services/auto_backup.dart';
import '../../services/backup.dart';
import '../../services/csv_export.dart';
import '../../services/oinkoin_import.dart';
import '../../state/app_state.dart';
import '../../utils/app_version.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _currencies = ['₺', '\$', '€', '£', '¥', '₽', 'CHF'];

  Future<void> _import(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: l.pickOinkoinBackup,
      type: FileType.any,
    );
    if (file == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String message;
    try {
      final text = utf8.decode(await file.readAsBytes());
      final s = await state.importOinkoin(text);
      message = l.importDone(
        s.recordsAdded,
        s.transfersAdded,
        s.categoriesAdded,
        s.walletsAdded,
        s.rulesAdded,
      );
      if (s.recordsSkipped > 0) {
        message += ' ${l.importSkipped(s.recordsSkipped)}';
      }
    } on OinkoinImportException catch (e) {
      message = switch (e.error) {
        OinkoinImportError.notJson => l.importNotJson,
        OinkoinImportError.notOinkoinBackup => l.importNotOinkoin,
      };
    } on FormatException {
      message = l.importNotUtf8;
    } catch (e) {
      message = l.importFailed('$e');
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backup(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await state.exportBackupText();
      final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uri = await FilePicker.saveFile(
        dialogTitle: l.backupCreate,
        fileName: 'yasba-backup-$day.json',
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: 'application/json',
      );
      // Null when the user cancelled the save dialog.
      if (uri != null) {
        messenger.showSnackBar(SnackBar(content: Text(l.backupSaved)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.backupFailed('$e'))));
    }
  }

  Future<void> _setReminders(
    BuildContext context, {
    bool? recurring,
    bool? debts,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<AppState>().setReminders(
      recurring: recurring,
      debts: debts,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await state.exportCsvText(
        CsvLabels(
          headers: [
            l.csvDate,
            l.csvType,
            l.category,
            l.wallet,
            l.csvToWallet,
            l.csvTitle,
            l.csvNote,
            l.amount,
            l.currency,
          ],
          income: l.income,
          expense: l.expense,
          transfer: l.transfer,
          debtLent: l.debtLentEvent,
          debtBorrowed: l.debtBorrowedEvent,
          repaymentReceived: l.repaymentReceived,
          repaymentMade: l.repaymentMade,
          closedUncollected: l.closedUncollectedEvent,
          closedUnpaid: l.closedUnpaidEvent,
        ),
      );
      final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uri = await FilePicker.saveFile(
        dialogTitle: l.exportCsv,
        fileName: 'yasba-$day.csv',
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: 'text/csv',
      );
      if (uri != null) {
        messenger.showSnackBar(SnackBar(content: Text(l.exportCsvSaved)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.backupFailed('$e'))));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: l.backupPick,
      type: FileType.any,
    );
    if (file == null || !context.mounted) return;

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
      return;
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.importNotUtf8)));
      return;
    }
    if (!context.mounted) return;

    final date = backup.createdAt == null
        ? l.unknownDate
        : DateFormat.yMMMd().add_Hm().format(backup.createdAt!.toLocal());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.backupRestoreQuestion),
        content: Text(
          l.backupRestoreDetails(
            date,
            backup.count('wallets'),
            backup.count('records'),
            backup.count('transfers'),
            backup.count('recurring_rules'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.backupRestoreConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String message;
    try {
      await state.restoreFromBackup(backup);
      message = l.backupRestored;
    } catch (e) {
      message = l.importFailed('$e');
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _autoBackupStatus(AppLocalizations l, AppState state) {
    if (state.autoBackup == AutoBackupFrequency.off) return l.autoBackupOffHint;
    if (state.autoBackupError != null) {
      return l.autoBackupFailed(state.autoBackupError!);
    }
    final last = state.lastAutoBackup;
    if (last == null) return l.autoBackupNever;
    final date = DateFormat.yMMMd().add_Hm().format(last);
    final where = state.autoBackupLocation;
    return where == null
        ? l.autoBackupLast(date)
        : '${l.autoBackupLast(date)}\n$where';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(l.currency),
            trailing: DropdownButton<String>(
              value: _currencies.contains(state.currency)
                  ? state.currency
                  : null,
              hint: Text(state.currency),
              underline: const SizedBox.shrink(),
              items: [
                for (final c in _currencies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) state.setCurrency(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: DropdownButton<String>(
              value: state.language,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: '', child: Text(l.languageSystem)),
                // Language names are always shown in their own language.
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
              ],
              onChanged: (v) {
                if (v != null) state.setLanguage(v);
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l.reminders,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: Text(l.remindRecurring),
            subtitle: Text(l.remindersHint),
            value: state.remindRecurring,
            onChanged: (v) => _setReminders(context, recurring: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.event_outlined),
            title: Text(l.remindDebts),
            value: state.remindDebts,
            onChanged: (v) => _setReminders(context, debts: v),
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: Text(l.remindTime),
            enabled: state.remindRecurring || state.remindDebts,
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay(hour: state.remindHour, minute: state.remindMinute),
                alwaysUse24HourFormat: true,
              ),
            ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: state.remindHour,
                  minute: state.remindMinute,
                ),
              );
              if (t != null) await state.setReminderTime(t.hour, t.minute);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.backupCreate),
            subtitle: Text(l.backupCreateHint),
            onTap: () => _backup(context),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l.autoBackup),
            subtitle: Text(_autoBackupStatus(l, state)),
            isThreeLine: true,
            trailing: DropdownButton<AutoBackupFrequency>(
              value: state.autoBackup,
              underline: const SizedBox.shrink(),
              items: [
                for (final f in AutoBackupFrequency.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(switch (f) {
                      AutoBackupFrequency.off => l.autoBackupOff,
                      AutoBackupFrequency.daily => l.autoBackupDaily,
                      AutoBackupFrequency.weekly => l.autoBackupWeekly,
                      AutoBackupFrequency.monthly => l.autoBackupMonthly,
                    }),
                  ),
              ],
              onChanged: (f) {
                if (f != null) state.setAutoBackup(f);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l.backupRestore),
            subtitle: Text(l.backupRestoreHint),
            onTap: () => _restore(context),
          ),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: Text(l.exportCsv),
            subtitle: Text(l.exportCsvHint),
            onTap: () => _exportCsv(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l.importOinkoin),
            subtitle: Text(l.importOinkoinHint),
            onTap: () => _import(context),
          ),
          const Divider(),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: 'YASBA',
            applicationVersion: appVersion,
            applicationLegalese: l.aboutLegalese,
          ),
        ],
      ),
    );
  }
}
