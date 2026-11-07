import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/record.dart';
import '../../models/transfer.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import '../widgets/month_selector.dart';
import '../widgets/wallet_filter_bar.dart';
import 'edit_record_page.dart';

/// A record or a transfer, for the mixed list.
DateTime _dateOf(Object e) => e is Record ? e.date : (e as Transfer).date;

/// How a transfer changes the filtered wallet's balance; 0 without a filter.
int _transferEffect(AppState state, Transfer t) {
  final w = state.walletFilter;
  if (w == null) return 0;
  if (t.toWalletId == w) return t.amount;
  if (t.fromWalletId == w) return -t.amount;
  return 0;
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final entries = <Object>[...state.monthRecords, ...state.monthTransfers]
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    // Group by day (entries are sorted newest first).
    final groups = <DateTime, List<Object>>{};
    for (final e in entries) {
      final d = _dateOf(e);
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: MonthSelector(month: state.month, onChanged: state.setMonth),
        centerTitle: true,
        bottom: state.wallets.length > 1
            ? const PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: WalletFilterBar(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.addRecord),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditRecordPage())),
      ),
      body: GestureDetector(
        // Swipe left/right to change the month.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          state.shiftMonth(v < 0 ? 1 : -1);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _SummaryCard(state: state),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(child: Text(l.noRecordsThisMonth)),
              ),
            for (final group in groups.entries) ...[
              _DayHeader(day: group.key, entries: group.value, state: state),
              for (final e in group.value)
                e is Record
                    ? _RecordTile(record: e)
                    : _TransferTile(transfer: e as Transfer),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final income = state.monthIncome;
    final expense = state.monthExpense;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget cell(String label, int value, Color color) => Expanded(
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
    final wallet = state.walletById(state.walletFilter);
    final balance = wallet == null
        ? state.totalBalance
        : state.balances[wallet.id] ?? 0;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Row(
              children: [
                cell(l.income, income, Colors.green.shade600),
                cell(l.expense, expense, scheme.error),
                cell(
                  l.balance,
                  income - expense,
                  income - expense >= 0 ? scheme.primary : scheme.error,
                ),
              ],
            ),
            // Current balance of the filtered wallet or of all wallets.
            if (state.wallets.length > 1) ...[
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        wallet?.name ?? l.totalBalance,
                        style: text.labelLarge,
                      ),
                    ),
                    Text(
                      formatMoney(balance, state.currency),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: balance < 0 ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.entries,
    required this.state,
  });

  final DateTime day;
  final List<Object> entries;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(
      0,
      (s, e) =>
          s +
          (e is Record
              ? state.signedAmount(e)
              : _transferEffect(state, e as Transfer)),
    );
    final style = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(DateFormat.MMMMEEEEd().format(day), style: style),
          ),
          Text(formatMoney(total, state.currency, signed: true), style: style),
        ],
      ),
    );
  }
}

/// Swipe-to-delete wrapper with an undo action.
class _Deletable extends StatelessWidget {
  const _Deletable({
    required this.id,
    required this.onDelete,
    required this.onUndo,
    required this.deletedText,
    required this.child,
  });

  final String id;
  final Future<void> Function() onDelete;
  final VoidCallback onUndo;
  final String deletedText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await onDelete();
        messenger.showSnackBar(
          SnackBar(
            content: Text(deletedText),
            action: SnackBarAction(label: l.undo, onPressed: onUndo),
          ),
        );
      },
      child: child,
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final Record record;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final category = state.categoryById(record.categoryId);
    final income = state.isIncome(record);
    final title = record.title.isNotEmpty
        ? record.title
        : (category?.name ?? '?');
    // Without a wallet filter, say which wallet the record belongs to.
    final wallet = state.wallets.length > 1 && state.walletFilter == null
        ? state.walletById(record.walletId)
        : null;
    return _Deletable(
      id: 'record-${record.id}',
      deletedText: l.recordDeleted,
      onDelete: () => state.deleteRecord(record),
      onUndo: () => state.restoreRecord(record),
      child: ListTile(
        leading: CategoryAvatar(category: category),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (record.title.isNotEmpty && category != null) category.name,
            if (wallet != null) wallet.name,
            if (record.note != null) record.note!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record.recurringId != null)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.repeat, size: 16),
              ),
            Text(
              formatMoney(
                income ? record.amount : -record.amount,
                state.currency,
              ),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: income ? Colors.green.shade600 : null,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditRecordPage(record: record)),
        ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final from = state.walletById(transfer.fromWalletId)?.name ?? '?';
    final to = state.walletById(transfer.toWalletId)?.name ?? '?';
    final effect = _transferEffect(state, transfer);
    return _Deletable(
      id: 'transfer-${transfer.id}',
      deletedText: l.transferDeleted,
      onDelete: () => state.deleteTransfer(transfer),
      onUndo: () => state.restoreTransfer(transfer),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: const Icon(Icons.swap_horiz),
        ),
        // An icon rather than "→", which some fonts lack.
        title: Row(
          children: [
            Flexible(child: Text(from, overflow: TextOverflow.ellipsis)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 18),
            ),
            Flexible(child: Text(to, overflow: TextOverflow.ellipsis)),
          ],
        ),
        subtitle: Text(
          [l.transfer, if (transfer.note != null) transfer.note!].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          // Signed only when looking at one wallet; neutral otherwise.
          formatMoney(effect == 0 ? transfer.amount : effect, state.currency),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: effect > 0 ? Colors.green.shade600 : scheme.onSurfaceVariant,
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditRecordPage(transfer: transfer)),
        ),
      ),
    );
  }
}
