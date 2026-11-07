import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../models/record.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_picker.dart';

class EditRecordPage extends StatefulWidget {
  const EditRecordPage({super.key, this.record});

  final Record? record;

  @override
  State<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends State<EditRecordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _note;
  late CategoryType _type;
  int? _categoryId;
  late DateTime _date;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final r = widget.record;
    _amount = TextEditingController(
      text: r == null
          ? ''
          : (r.amount / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _title = TextEditingController(text: r?.title ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _categoryId = r?.categoryId;
    _type = r == null
        ? CategoryType.expense
        : (state.categoryById(r.categoryId)?.type ?? CategoryType.expense);
    final now = DateTime.now();
    // For a new record, default to the 1st of the selected month unless it is
    // the current month.
    final m = state.month;
    _date = r?.date ?? (m.year == now.year && m.month == now.month ? now : m);
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.pickCategory)));
      return;
    }
    final note = _note.text.trim();
    final record = Record(
      id: widget.record?.id,
      title: _title.text.trim(),
      amount: parseMoney(_amount.text)!,
      date: _date,
      categoryId: _categoryId!,
      note: note.isEmpty ? null : note,
      recurringId: widget.record?.recurringId,
    );
    await context.read<AppState>().saveRecord(record);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteRecordQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteRecord(widget.record!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final categories = state.categories
        .where((c) => c.type == _type && (!c.archived || c.id == _categoryId))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editRecord : l.newRecord),
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
            SegmentedButton<CategoryType>(
              segments: [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text(l.expense),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text(l.income),
                  icon: Icon(Icons.add),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (state.categoryById(_categoryId ?? -1)?.type != _type) {
                  _categoryId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: l.amount,
                suffixText: state.currency,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final cents = parseMoney(v ?? '');
                return (cents == null || cents == 0) ? l.invalidAmount : null;
              },
            ),
            const SizedBox(height: 16),
            Text(l.category, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryPicker(
              categories: categories,
              selectedId: _categoryId,
              onSelected: (c) => setState(() => _categoryId = c.id),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.titleOptional,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat.yMMMMEEEEd().format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
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
