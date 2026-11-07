import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/oinkoin_import.dart';
import '../../state/app_state.dart';
import 'categories_page.dart';
import 'recurring_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _currencies = ['₺', '\$', '€', '£', '¥', '₽', 'CHF'];

  Future<void> _import(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: 'Oinkoin yedeğini seçin',
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
      message =
          'İçe aktarıldı: ${s.recordsAdded} kayıt, '
          '${s.categoriesAdded} kategori, ${s.rulesAdded} tekrarlayan.'
          '${s.recordsSkipped > 0 ? ' ${s.recordsSkipped} kayıt zaten vardı.' : ''}';
    } on OinkoinImportException catch (e) {
      message = e.message;
    } on FormatException {
      message = 'Dosya okunamadı (UTF-8 değil).';
    } catch (e) {
      message = 'İçe aktarma başarısız: $e';
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Kategoriler'),
            subtitle: Text('${state.categories.length} kategori'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CategoriesPage())),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Tekrarlayan işlemler'),
            subtitle: Text('${state.rules.length} kural'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RecurringPage())),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Para birimi'),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Oinkoin yedeğini içe aktar'),
            subtitle: const Text(
              'Oinkoin > Ayarlar > Yedekle ile aldığınız .json dosyası',
            ),
            onTap: () => _import(context),
          ),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'YAFA',
            applicationVersion: '0.1.0',
            applicationLegalese:
                'Yet Another Financial App\nTüm verileriniz cihazınızda kalır.',
          ),
        ],
      ),
    );
  }
}
