import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../services/oinkoin_import.dart';
import '../../state/app_state.dart';
import 'categories_page.dart';
import 'recurring_page.dart';

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
      message = l.importDone(s.recordsAdded, s.categoriesAdded, s.rulesAdded);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(l.categories),
            subtitle: Text(l.categoryCount(state.categories.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CategoriesPage())),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(l.recurringTransactions),
            subtitle: Text(l.ruleCount(state.rules.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RecurringPage())),
          ),
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
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l.importOinkoin),
            subtitle: Text(l.importOinkoinHint),
            onTap: () => _import(context),
          ),
          const Divider(),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: 'YAFA',
            applicationVersion: '0.1.0',
            applicationLegalese: l.aboutLegalese,
          ),
        ],
      ),
    );
  }
}
