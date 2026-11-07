import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import 'category_avatar.dart';

/// Shows categories as chips and lets the user pick one.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(8),
        child: Text(l.noCategoriesOfType),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ChoiceChip(
            avatar: CategoryAvatar(category: c, radius: 12),
            label: Text(c.name),
            selected: c.id == selectedId,
            onSelected: (_) => onSelected(c),
          ),
      ],
    );
  }
}
