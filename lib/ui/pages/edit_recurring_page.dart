import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/recurring_rule.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_picker.dart';

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
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir kategori seçin')),
      );
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
    );
    final messenger = ScaffoldMessenger.of(context);
    final created = await context.read<AppState>().saveRule(rule);
    if (created > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('$created geçmiş kayıt otomatik oluşturuldu')),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tekrarlayan işlem silinsin mi?'),
        content: const Text(
          'Daha önce oluşturulmuş kayıtlar silinmez, sadece yenileri oluşmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
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
    final state = context.watch<AppState>();
    final categories = state.categories
        .where((c) => c.type == _type && (!c.archived || c.id == _categoryId))
        .toList();
    final fmt = DateFormat('d MMMM y', 'tr_TR');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Tekrarlayanı düzenle' : 'Yeni tekrarlayan'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Sil',
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
              segments: const [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text('Gider'),
                ),
                ButtonSegment(value: CategoryType.income, label: Text('Gelir')),
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
                labelText: 'Tutar',
                suffixText: state.currency,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final cents = parseMoney(v ?? '');
                return (cents == null || cents == 0)
                    ? 'Geçerli bir tutar girin'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Başlık (ör. Kira, Netflix)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryPicker(
              categories: categories,
              selectedId: _categoryId,
              onSelected: (c) => setState(() => _categoryId = c.id),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Her'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _interval,
                    keyboardType: TextInputType.number,
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
                    items: const [
                      DropdownMenuItem(
                        value: RecurrenceUnit.day,
                        child: Text('gün'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceUnit.week,
                        child: Text('hafta'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceUnit.month,
                        child: Text('ay'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceUnit.year,
                        child: Text('yıl'),
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
              title: const Text('Başlangıç'),
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
              title: const Text('Bitiş (isteğe bağlı)'),
              subtitle: Text(_end == null ? 'Süresiz' : fmt.format(_end!)),
              trailing: _end == null
                  ? null
                  : IconButton(
                      tooltip: 'Bitişi kaldır',
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
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
