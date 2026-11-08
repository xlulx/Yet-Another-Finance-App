import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../state/app_state.dart';
import '../widgets/category_avatar.dart';
import 'edit_category_page.dart';

/// Categories page, opened from the side menu. The add button creates a
/// category of the type being shown.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _type = ValueNotifier(CategoryType.expense);

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.categories)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.addCategory,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditCategoryPage(initialType: _type.value),
          ),
        ),
      ),
      body: CategoriesTab(type: _type),
    );
  }
}

/// Categories of one type, chosen with buttons above the list. [type] is
/// shared with the page's add button.
class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key, required this.type});

  final ValueNotifier<CategoryType> type;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<CategoryType>(
      valueListenable: type,
      builder: (context, current, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CategoryType>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text(l.expense),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text(l.income),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (s) => type.value = s.first,
              ),
            ),
          ),
          Expanded(child: _CategoryList(type: current)),
        ],
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
