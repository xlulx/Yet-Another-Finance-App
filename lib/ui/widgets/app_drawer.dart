import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../pages/categories_page.dart';
import '../pages/debts_page.dart';
import '../pages/recurring_page.dart';
import '../pages/settings_page.dart';

/// Side menu with the less frequently used pages. Opened with the ☰ button
/// on the main pages or by swiping from the left edge.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    void open(Widget page) {
      Navigator.of(context)
        ..pop() // Close the menu first.
        ..push(MaterialPageRoute(builder: (_) => page));
    }

    // Plain list tiles: long labels such as "Recurring transactions" wrap
    // instead of overflowing.
    Widget item(IconData icon, String label, Widget page) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      onTap: () => open(page),
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 4),
              child: Text('YASBA', style: text.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 16, 16),
              child: Text(l.tagline, style: text.bodyMedium),
            ),
            item(Icons.category_outlined, l.categories, const CategoriesPage()),
            item(Icons.repeat, l.recurringTransactions, const RecurringPage()),
            item(Icons.handshake_outlined, l.debts, const DebtsPage()),
            const Divider(indent: 28, endIndent: 28),
            item(Icons.settings_outlined, l.settings, const SettingsPage()),
          ],
        ),
      ),
    );
  }
}
