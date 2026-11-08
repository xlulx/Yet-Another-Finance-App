import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/debt.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/wallet_dropdown.dart';
import '../widgets/dialogs.dart';

/// Colour for money owed to me (green) or by me (red).
Color _debtColor(BuildContext context, Debt d) =>
    d.lent ? Colors.green.shade600 : Theme.of(context).colorScheme.error;

/// What was written off when [d] was closed by hand with money still owed;
/// 0 otherwise.
int _writtenOff(AppState state, Debt d) {
  if (!d.closed) return 0;
  final remaining = state.remainingOf(d);
  return remaining > 0 ? remaining : 0;
}

/// Colour of a written-off amount: a loss (money lent) is red, a gain
/// (money borrowed) green.
Color _writtenOffColor(BuildContext context, Debt d) =>
    d.lent ? Theme.of(context).colorScheme.error : Colors.green.shade600;

bool _overdue(AppState state, Debt d) {
  final due = d.dueDate;
  if (due == null || state.isSettled(d)) return false;
  final today = DateTime.now();
  return due.isBefore(DateTime(today.year, today.month, today.day));
}

/// All debts: totals at the top, open ones first, settled ones below.
class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    final open = state.debts.where((d) => !state.isSettled(d)).toList();
    final settled = state.debts.where(state.isSettled).toList();

    Widget total(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: text.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatMoney(value, state.currency),
              style: text.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.debts)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.addDebt),
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const EditDebtPage())),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  total(l.owedToMe, state.totalOwedToMe, Colors.green.shade600),
                  total(
                    l.iOwe,
                    state.totalIOwe,
                    Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
          ),
          if (state.debts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.debtsEmpty, textAlign: TextAlign.center),
            ),
          if (open.isNotEmpty) _Header(l.openDebts),
          for (final d in open) _DebtTile(debt: d),
          if (settled.isNotEmpty) _Header(l.settledDebts),
          for (final d in settled) _DebtTile(debt: d),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final settled = state.isSettled(debt);
    final remaining = state.remainingOf(debt);
    final color = _debtColor(context, debt);
    final overdue = _overdue(state, debt);
    final paid = state.paidOf(debt);
    final writtenOff = _writtenOff(state, debt);
    return Opacity(
      opacity: settled && writtenOff == 0 ? 0.6 : 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(debt.lent ? Icons.call_made : Icons.call_received),
        ),
        title: Text(
          debt.lent ? l.theyOweMe(debt.person) : l.iOweThem(debt.person),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
                DateFormat.yMMMd().format(debt.date),
                if (writtenOff > 0)
                  debt.lent ? l.closedUncollected : l.closedUnpaid
                else if (settled)
                  l.settled
                else if (overdue)
                  l.overdue
                else if (debt.dueDate != null)
                  l.dueOn(DateFormat.yMMMd().format(debt.dueDate!)),
              ].join(' · ') +
              (!settled && paid > 0
                  ? '\n${l.remainingOf(formatMoney(remaining, state.currency), formatMoney(debt.amount, state.currency))}'
                  : ''),
          style: overdue
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        trailing: writtenOff > 0
            // Closed with money owed: the loss or gain, in full colour.
            ? Text(
                formatMoney(
                  debt.lent ? -writtenOff : writtenOff,
                  state.currency,
                  signed: true,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _writtenOffColor(context, debt),
                ),
              )
            : Text(
                formatMoney(settled ? debt.amount : remaining, state.currency),
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtDetailPage(debtId: debt.id!)),
        ),
      ),
    );
  }
}

/// Adds or edits a debt.
class EditDebtPage extends StatefulWidget {
  const EditDebtPage({super.key, this.debt});
  final Debt? debt;

  @override
  State<EditDebtPage> createState() => _EditDebtPageState();
}

class _EditDebtPageState extends State<EditDebtPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _person;
  final _personFocus = FocusNode();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DebtDirection _direction;
  late DateTime _date;
  DateTime? _due;
  int? _walletId;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final d = widget.debt;
    _person = TextEditingController(text: d?.person ?? '');
    _amount = TextEditingController(
      text: d == null
          ? ''
          : (d.amount / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _note = TextEditingController(text: d?.note ?? '');
    _direction = d?.direction ?? DebtDirection.lent;
    _date = d?.date ?? DateTime.now();
    _due = d?.dueDate;
    _walletId = d == null ? state.defaultWalletId : d.walletId;
  }

  @override
  void dispose() {
    _person.dispose();
    _personFocus.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => pickDate(context, initial);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = _note.text.trim();
    await context.read<AppState>().saveDebt(
      Debt(
        id: widget.debt?.id,
        person: _person.text.trim(),
        direction: _direction,
        amount: parseMoney(_amount.text)!,
        date: _date,
        dueDate: _due,
        note: note.isEmpty ? null : note,
        walletId: _walletId,
        closed: widget.debt?.closed ?? false,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final fmt = DateFormat.yMMMMd();
    return Scaffold(
      appBar: AppBar(title: Text(widget.debt == null ? l.newDebt : l.editDebt)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<DebtDirection>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: DebtDirection.lent,
                  label: Text(l.debtLent),
                  icon: const Icon(Icons.call_made),
                ),
                ButtonSegment(
                  value: DebtDirection.borrowed,
                  label: Text(l.debtBorrowed),
                  icon: const Icon(Icons.call_received),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 16),
            // Suggests names already used, typed into our own controller.
            RawAutocomplete<String>(
              textEditingController: _person,
              focusNode: _personFocus,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const [];
                return state.debtPeople.where(
                  (p) => p.toLowerCase().contains(q) && p.toLowerCase() != q,
                );
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) =>
                  TextFormField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: widget.debt == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.person,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? l.personRequired : null,
                  ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 220,
                      maxWidth: 320,
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(title: Text(o), onTap: () => onSelected(o)),
                      ],
                    ),
                  ),
                ),
              ),
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
            WalletDropdown.optional(
              label: l.wallet,
              noneLabel: l.noWallet,
              wallets: state.wallets,
              value: _walletId,
              onSelected: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(fmt.format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await _pick(_date);
                if (d != null) setState(() => _date = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text(l.dueDateOptional),
              subtitle: Text(_due == null ? l.noDueDate : fmt.format(_due!)),
              trailing: _due == null
                  ? null
                  : IconButton(
                      tooltip: l.removeDueDate,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: () async {
                final d = await _pick(_due ?? _date);
                if (d != null) setState(() => _due = d);
              },
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

/// One debt with its payments; payments are added and removed here.
class DebtDetailPage extends StatelessWidget {
  const DebtDetailPage({super.key, required this.debtId});
  final int debtId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final debt = state.debts.where((d) => d.id == debtId).firstOrNull;
    // Deleted from this page: nothing left to show.
    if (debt == null) return const Scaffold();
    final text = Theme.of(context).textTheme;
    final color = _debtColor(context, debt);
    final settled = state.isSettled(debt);
    final remaining = state.remainingOf(debt);
    final payments = state.paymentsOf(debt).reversed.toList();
    final wallet = state.walletById(debt.walletId);

    Widget figure(String label, int value, {Color? valueColor}) => Expanded(
      child: Column(
        children: [
          Text(label, style: text.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatMoney(value, state.currency),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.person),
        actions: [
          IconButton(
            tooltip: l.editDebt,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => EditDebtPage(debt: debt))),
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await confirm(
                context,
                title: l.deleteDebtQuestion,
                action: l.delete,
              );
              if (!ok) return;
              await state.deleteDebt(debt);
              navigator.pop();
            },
          ),
        ],
      ),
      floatingActionButton: settled
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l.addPayment),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _PaymentDialog(debt: debt),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ListTile(
            title: Text(
              debt.lent ? l.theyOweMe(debt.person) : l.iOweThem(debt.person),
              style: text.titleMedium?.copyWith(color: color),
            ),
            subtitle: Text(
              [
                DateFormat.yMMMMd().format(debt.date),
                if (wallet != null) wallet.name,
                if (debt.dueDate != null)
                  l.dueOn(DateFormat.yMMMd().format(debt.dueDate!)),
                if (debt.note != null) debt.note!,
              ].join(' · '),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  figure(l.total, debt.amount),
                  figure(l.paid, state.paidOf(debt)),
                  if (_writtenOff(state, debt) > 0)
                    figure(
                      l.closedDifference,
                      remaining,
                      valueColor: _writtenOffColor(context, debt),
                    )
                  else
                    figure(
                      l.remaining,
                      remaining < 0 ? 0 : remaining,
                      valueColor: color,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: Icon(settled ? Icons.undo : Icons.task_alt),
                label: Text(settled ? l.reopenDebt : l.closeDebt),
                onPressed: () async {
                  // Closing with money owed makes it an expense or income.
                  if (!settled && remaining > 0) {
                    final amount = formatMoney(remaining, state.currency);
                    final ok = await confirm(
                      context,
                      title: l.closeDebtQuestion,
                      message: debt.lent
                          ? l.closeDebtLossHint(amount)
                          : l.closeDebtGainHint(amount),
                      action: l.closeDebt,
                      destructive: false,
                    );
                    if (!ok) return;
                  }
                  await state.setDebtClosed(debt, !settled);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.payments, style: text.titleSmall),
          ),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.noPayments),
            ),
          for (final p in payments)
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(formatMoney(p.amount, state.currency)),
              subtitle: Text(
                [
                  DateFormat.yMMMd().format(p.date),
                  if (state.walletById(p.walletId) != null)
                    state.walletById(p.walletId)!.name,
                  if (p.note != null) p.note!,
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!await confirm(
                    context,
                    title: l.deletePaymentQuestion,
                    action: l.delete,
                  )) {
                    return;
                  }
                  await state.deleteDebtPayment(p);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Records a repayment, by default of the whole remaining amount into (or
/// out of) the debt's wallet.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.debt});
  final Debt debt;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final int _remaining;
  late DateTime _date = DateTime.now();
  int? _walletId;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _remaining = state.remainingOf(widget.debt);
    _amount = TextEditingController(
      text: (_remaining / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _walletId = widget.debt.walletId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().addDebtPayment(
      DebtPayment(
        debtId: widget.debt.id!,
        amount: parseMoney(_amount.text)!,
        date: _date,
        walletId: _walletId,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    return AlertDialog(
      title: Text(l.addPayment),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                autofocus: true,
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
                  if (cents == null || cents == 0) return l.invalidAmount;
                  if (cents > _remaining) {
                    return l.paymentTooBig(
                      formatMoney(_remaining, state.currency),
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              WalletDropdown.optional(
                label: l.wallet,
                noneLabel: l.noWallet,
                wallets: state.wallets,
                value: _walletId,
                onSelected: (v) => setState(() => _walletId = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(DateFormat.yMMMMd().format(_date)),
                onTap: () async {
                  final d = await pickDate(context, _date);
                  if (d != null) setState(() => _date = d);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
