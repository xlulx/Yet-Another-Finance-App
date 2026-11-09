import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/record.dart';
import '../../models/transfer.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_picker.dart';
import '../widgets/wallet_dropdown.dart';
import '../widgets/dialogs.dart';

enum _Kind { expense, income, transfer }

/// Adds or edits an income/expense record or a transfer between wallets.
/// Pass [record] or [transfer] to edit; the type can be switched either way.
class EditRecordPage extends StatefulWidget {
  const EditRecordPage({super.key, this.record, this.transfer});

  final Record? record;
  final Transfer? transfer;

  @override
  State<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends State<EditRecordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _note;
  late _Kind _kind;
  int? _categoryId;
  late int _walletId;
  int? _toWalletId;
  late DateTime _date;

  bool get _isEdit => widget.record != null || widget.transfer != null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final r = widget.record;
    final t = widget.transfer;
    final cents = r?.amount ?? t?.amount;
    _amount = TextEditingController(
      text: cents == null
          ? ''
          : (cents / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _title = TextEditingController(text: r?.title ?? '');
    _note = TextEditingController(text: r?.note ?? t?.note ?? '');
    _categoryId = r?.categoryId;
    if (t != null) {
      _kind = _Kind.transfer;
    } else if (r != null &&
        state.categoryById(r.categoryId)?.type == CategoryType.income) {
      _kind = _Kind.income;
    } else {
      _kind = _Kind.expense;
    }
    _walletId = t?.fromWalletId ?? r?.walletId ?? state.defaultWalletId;
    _toWalletId = t?.toWalletId;
    final now = DateTime.now();
    // For a new entry, default to today, or the first day of the period
    // shown if today is not in it.
    _date =
        r?.date ??
        t?.date ??
        (state.period.contains(now) ? now : state.period.from);
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(context, _date);
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
    final state = context.read<AppState>();
    if (!_formKey.currentState!.validate()) return;
    if (_kind != _Kind.transfer && _categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.pickCategory)));
      return;
    }
    final note = _note.text.trim();
    final amount = parseMoney(_amount.text)!;
    final oldRecord = widget.record;
    final oldTransfer = widget.transfer;

    if (_kind == _Kind.transfer) {
      final t = Transfer(
        id: oldTransfer?.id,
        fromWalletId: _walletId,
        toWalletId: _toWalletId!,
        amount: amount,
        date: _date,
        note: note.isEmpty ? null : note,
      );
      if (oldRecord != null) {
        await state.replaceEntry(oldRecord: oldRecord, newTransfer: t);
      } else {
        await state.saveTransfer(t);
      }
    } else {
      final r = Record(
        id: oldRecord?.id,
        title: _title.text.trim(),
        amount: amount,
        date: _date,
        categoryId: _categoryId!,
        note: note.isEmpty ? null : note,
        recurringId: oldRecord?.recurringId,
        walletId: _walletId,
      );
      if (oldTransfer != null) {
        await state.replaceEntry(oldTransfer: oldTransfer, newRecord: r);
      } else {
        await state.saveRecord(r);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final ok = await confirm(
      context,
      title: widget.transfer != null
          ? l.deleteTransferQuestion
          : l.deleteRecordQuestion,
      action: l.delete,
    );
    if (!ok || !mounted) return;
    if (widget.transfer != null) {
      await state.deleteTransfer(widget.transfer!);
    } else {
      await state.deleteRecord(widget.record!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _setKind(_Kind kind, AppState state) {
    setState(() {
      _kind = kind;
      if (kind == _Kind.transfer) {
        // Preselect a destination different from the source.
        _toWalletId ??= state.activeWallets
            .where((w) => w.id != _walletId)
            .map((w) => w.id)
            .firstOrNull;
        return;
      }
      final type = kind == _Kind.income
          ? CategoryType.income
          : CategoryType.expense;
      if (state.categoryById(_categoryId ?? -1)?.type != type) {
        _categoryId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final isTransfer = _kind == _Kind.transfer;
    final type = _kind == _Kind.income
        ? CategoryType.income
        : CategoryType.expense;
    final categories = state.categories
        .where((c) => c.type == type && (!c.archived || c.id == _categoryId))
        .toList();
    // Transfers need two wallets; keep the option when editing one anyway.
    final canTransfer =
        state.activeWallets.length >= 2 || widget.transfer != null;
    final showWallet = state.wallets.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTransfer
              ? (_isEdit ? l.editTransfer : l.newTransfer)
              : (_isEdit ? l.editRecord : l.newRecord),
        ),
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
            SegmentedButton<_Kind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _Kind.expense,
                  label: Text(l.expense),
                  icon: const Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: _Kind.income,
                  label: Text(l.income),
                  icon: const Icon(Icons.add),
                ),
                if (canTransfer)
                  ButtonSegment(
                    value: _Kind.transfer,
                    label: Text(l.transfer),
                    icon: const Icon(Icons.swap_horiz),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => _setKind(s.first, state),
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
            if (isTransfer) ...[
              WalletDropdown(
                label: l.fromWallet,
                wallets: state.wallets,
                value: _walletId,
                onChanged: (v) => setState(() => _walletId = v),
              ),
              Center(
                child: IconButton(
                  tooltip: '${l.fromWallet} / ${l.toWallet}',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _toWalletId == null
                      ? null
                      : () => setState(() {
                          final from = _walletId;
                          _walletId = _toWalletId!;
                          _toWalletId = from;
                        }),
                ),
              ),
              WalletDropdown(
                label: l.toWallet,
                wallets: state.wallets,
                value: _toWalletId,
                onChanged: (v) => setState(() => _toWalletId = v),
                validator: (v) =>
                    (v == null || v == _walletId) ? l.sameWallet : null,
              ),
            ] else ...[
              Text(l.category, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              CategoryPicker(
                categories: categories,
                selectedId: _categoryId,
                onSelected: (c) => setState(() => _categoryId = c.id),
              ),
              if (showWallet) ...[
                const SizedBox(height: 16),
                WalletDropdown(
                  label: l.wallet,
                  wallets: state.wallets,
                  value: _walletId,
                  onChanged: (v) => setState(() => _walletId = v),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.titleOptional,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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
                border: const OutlineInputBorder(),
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
