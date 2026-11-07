import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../state/app_state.dart';
import '../widgets/category_avatar.dart';
import 'edit_category_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l.categories),
              bottom: TabBar(
                tabs: [
                  Tab(text: l.expense),
                  Tab(text: l.income),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              tooltip: l.addCategory,
              child: const Icon(Icons.add),
              onPressed: () {
                final tab = DefaultTabController.of(context).index;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EditCategoryPage(initialType: CategoryType.values[tab]),
                  ),
                );
              },
            ),
            body: const TabBarView(
              children: [
                _CategoryList(type: CategoryType.expense),
                _CategoryList(type: CategoryType.income),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final list = state.categories.where((c) => c.type == type).toList()
      ..sort((a, b) {
        if (a.archived != b.archived) return a.archived ? 1 : -1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    if (list.isEmpty) {
      return Center(child: Text(l.noCategoriesYet));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final c in list)
          ListTile(
            leading: Opacity(
              opacity: c.archived ? 0.4 : 1,
              child: CategoryAvatar(category: c),
            ),
            title: Text(c.name),
            subtitle: c.archived ? Text(l.archived) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EditCategoryPage(category: c)),
            ),
          ),
      ],
    );
  }
}
