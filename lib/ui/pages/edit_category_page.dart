import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../state/app_state.dart';
import '../../utils/category_icons.dart';
import '../widgets/category_avatar.dart';

class EditCategoryPage extends StatefulWidget {
  const EditCategoryPage({super.key, this.category, this.initialType});

  final Category? category;
  final CategoryType? initialType;

  @override
  State<EditCategoryPage> createState() => _EditCategoryPageState();
}

class _EditCategoryPageState extends State<EditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _emoji;
  late CategoryType _type;
  late int _color;
  late String _icon;
  late bool _archived;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _emoji = TextEditingController(text: c?.emoji ?? '');
    _type = c?.type ?? widget.initialType ?? CategoryType.expense;
    _color = c?.color ?? categoryColors[5];
    _icon = c?.icon ?? 'category';
    _archived = c?.archived ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Category get _draft {
    final emoji = _emoji.text.trim();
    return Category(
      id: widget.category?.id,
      name: _name.text.trim(),
      type: _type,
      color: _color,
      icon: _icon,
      emoji: emoji.isEmpty ? null : emoji,
      archived: _archived,
      sortOrder: widget.category?.sortOrder ?? 0,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().saveCategory(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final c = widget.category!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteCategoryQuestion(c.name)),
        content: Text(l.deleteCategoryWarning),
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
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.deleteCategory(c);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editCategory : l.newCategory),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: CategoryAvatar(category: _draft, radius: 36)),
            const SizedBox(height: 16),
            if (!_isEdit) ...[
              SegmentedButton<CategoryType>(
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
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.name,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return l.nameRequired;
                if (state.categoryNameTaken(
                  name,
                  _type,
                  exceptId: widget.category?.id,
                )) {
                  return l.nameTaken;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emoji,
              decoration: InputDecoration(
                labelText: l.emojiOptional,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text(l.colour, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in categoryColors)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(color),
                      child: color == _color
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.icon, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in categoryIcons.entries)
                  IconButton.outlined(
                    isSelected: entry.key == _icon,
                    icon: Icon(entry.value),
                    onPressed: () => setState(() {
                      _icon = entry.key;
                      _emoji.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.archive),
                subtitle: Text(l.archiveHint),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
