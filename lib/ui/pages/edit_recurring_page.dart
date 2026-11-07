import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../models/recurring_rule.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_picker.dart';
import '../widgets/wallet_dropdown.dart';
import 'recurring_page.dart' show unitName;

class EditRecurringPage extends StatefulWidget {
  const EditRecurringPage({super.key, this.rule});

  final RecurringRule? rule;

  @override
  State<EditRecurringPage> createState() => _EditRecurringPageState();
}

class _EditRecurringPageState extends State<EditRecurringPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _interval;
  late CategoryType _type;
  int? _categoryId;
  late int _walletId;
  late DateTime _start;
  DateTime? _end;
  late RecurrenceUnit _unit;

  bool get _isEdit => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final r = widget.rule;
    _amount = TextEditingController(
      text: r == null
          ? ''
          : (r.amount / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _title = TextEditingController(text: r?.title ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _interval = TextEditingController(text: '${r?.interval ?? 1}');
    _categoryId = r?.categoryId;
    _walletId = r?.walletId ?? state.defaultWalletId;
    _type = r == null
        ? CategoryType.expense
        : (state.categoryById(r.categoryId)?.type ?? CategoryType.expense);
    _start = r?.startDate ?? DateTime.now();
    _end = r?.endDate;
    _unit = r?.unit ?? RecurrenceUnit.month;
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1990),
    lastDate: DateTime(2100),
  );

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.pickCategory)));
      return;
    }
    final note = _note.text.trim();
    final old = widget.rule;
    // Generation history is kept; the start date cannot be changed once
    // records have been generated (the field is disabled below).
    final rule = RecurringRule(
      id: old?.id,
      title: _title.text.trim(),
      amount: parseMoney(_amount.text)!,
      categoryId: _categoryId!,
      note: note.isEmpty ? null : note,
      startDate: _start,
      interval: int.parse(_interval.text),
      unit: _unit,
      endDate: _end,
      lastGenerated: old?.lastGenerated,
      walletId: _walletId,
    );
    final messenger = ScaffoldMessenger.of(context);
    final created = await context.read<AppState>().saveRule(rule);
    if (created > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.pastRecordsCreated(created))),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteRecurringQuestion),
        content: Text(l.deleteRecurringHint),
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
    await context.read<AppState>().deleteRule(widget.rule!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final categories = state.categories
        .where((c) => c.type == _type && (!c.archived || c.id == _categoryId))
        .toList();
    final fmt = DateFormat.yMMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editRecurring : l.newRecurring),
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
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text(l.income),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.recurringTitleHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.category, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryPicker(
              categories: categories,
              selectedId: _categoryId,
              onSelected: (c) => setState(() => _categoryId = c.id),
            ),
            if (state.wallets.length > 1) ...[
              const SizedBox(height: 16),
              WalletDropdown(
                label: l.wallet,
                wallets: state.wallets,
                value: _walletId,
                onChanged: (v) => setState(() => _walletId = v),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(l.every),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    // Refresh the unit names ("month" vs "months").
                    onChanged: (_) => setState(() {}),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 1 || n > 999) ? '1-999' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RecurrenceUnit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in RecurrenceUnit.values)
                        DropdownMenuItem(
                          value: u,
                          child: Text(
                            unitName(l, u, int.tryParse(_interval.text) ?? 1),
                          ),
                        ),
                    ],
                    onChanged: (u) => setState(() => _unit = u!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow),
              title: Text(l.start),
              subtitle: Text(fmt.format(_start)),
              enabled: !_isEdit || widget.rule!.lastGenerated == null,
              onTap: () async {
                final d = await _pick(_start);
                if (d != null) setState(() => _start = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop),
              title: Text(l.endOptional),
              subtitle: Text(_end == null ? l.noEnd : fmt.format(_end!)),
              trailing: _end == null
                  ? null
                  : IconButton(
                      tooltip: l.removeEnd,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _end = null),
                    ),
              onTap: () async {
                final d = await _pick(_end ?? _start);
                if (d != null) {
                  setState(
                    () => _end = DateTime(d.year, d.month, d.day, 23, 59, 59),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
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
