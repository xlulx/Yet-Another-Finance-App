import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import 'categories_page.dart';
import 'edit_category_page.dart';
import 'edit_recurring_page.dart';
import 'edit_wallet_page.dart';
import 'recurring_page.dart';
import 'wallets_page.dart';

enum ManageTab { wallets, categories, recurring }

/// Wallets, categories and recurring transactions as swipeable tabs.
class ManagePage extends StatefulWidget {
  const ManagePage({super.key, this.initialTab = ManageTab.wallets});

  final ManageTab initialTab;

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ManageTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  )..addListener(() => setState(() {}));

  /// Category type shown on the categories tab, used by the add button.
  final _categoryType = ValueNotifier(CategoryType.expense);

  @override
  void dispose() {
    _tabs.dispose();
    _categoryType.dispose();
    super.dispose();
  }

  void _add() {
    final Widget page = switch (ManageTab.values[_tabs.index]) {
      ManageTab.wallets => const EditWalletPage(),
      ManageTab.categories => EditCategoryPage(
        initialType: _categoryType.value,
      ),
      ManageTab.recurring => const EditRecurringPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tooltip = switch (ManageTab.values[_tabs.index]) {
      ManageTab.wallets => l.addWallet,
      ManageTab.categories => l.addCategory,
      ManageTab.recurring => l.add,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.manage),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              text: l.wallets,
            ),
            Tab(icon: const Icon(Icons.category_outlined), text: l.categories),
            Tab(icon: const Icon(Icons.repeat), text: l.recurringShort),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tooltip,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const WalletsTab(),
          CategoriesTab(type: _categoryType),
          const RecurringTab(),
        ],
      ),
    );
  }
}
