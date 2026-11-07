import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import 'categories_page.dart';
import 'edit_category_page.dart';
import 'edit_recurring_page.dart';
import 'recurring_page.dart';

enum ManageTab { categories, recurring }

/// Categories and recurring transactions as swipeable tabs.
class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ManageTab.values.length,
    vsync: this,
  )..addListener(() => setState(() {}));

  /// Category type shown on the categories tab, used by the add button.
  final _categoryType = ValueNotifier(CategoryType.expense);

  @override
  void dispose() {
    _tabs.dispose();
    _categoryType.dispose();
    super.dispose();
  }

  ManageTab get _current => ManageTab.values[_tabs.index];

  void _add() {
    final Widget page = switch (_current) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l.manage),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.category_outlined), text: l.categories),
            Tab(icon: const Icon(Icons.repeat), text: l.recurringShort),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Root pages stay alive side by side in the bottom navigation;
        // shared hero tags would clash when a new screen opens.
        heroTag: null,
        tooltip: switch (_current) {
          ManageTab.categories => l.addCategory,
          ManageTab.recurring => l.add,
        },
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          CategoriesTab(type: _categoryType),
          const RecurringTab(),
        ],
      ),
    );
  }
}
