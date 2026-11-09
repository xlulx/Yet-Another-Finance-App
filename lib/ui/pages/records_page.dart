import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/debt.dart';
import '../../models/record.dart';
import '../../models/transfer.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/menu_button.dart';
import '../widgets/category_avatar.dart';
import '../widgets/period_selector.dart';
import '../widgets/selected_wallet_chip.dart';
import 'debts_page.dart';
import 'edit_record_page.dart';

/// A record, transfer or debt movement, for the mixed lists.
DateTime dateOfEntry(Object e) => switch (e) {
  Record r => r.date,
  Transfer t => t.date,
  DebtEvent d => d.date,
  _ => throw ArgumentError(e),
};

/// How a transfer changes the filtered wallet's balance; 0 without a filter.
/// The list tile for a record, transfer or debt movement.
Widget entryTile(Object e) => switch (e) {
  Record r => RecordTile(record: r),
  Transfer t => TransferTile(transfer: t),
  final e => DebtEventTile(event: e as DebtEvent),
};

int _transferEffect(AppState state, Transfer t) {
  final w = state.walletFilter;
  if (w == null) return 0;
  if (t.toWalletId == w) return t.amount;
  if (t.fromWalletId == w) return -t.amount;
  return 0;
}

/// How a debt movement counts in a day's total: only closing a debt with
/// money still owed is a loss or gain.
int _debtEffect(DebtEvent e) => e.counts ? e.effect : 0;

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final entries = <Object>[
      ...state.periodRecords,
      ...state.periodTransfers,
      ...state.periodDebtEvents,
    ]..sort((a, b) => dateOfEntry(b).compareTo(dateOfEntry(a)));

    // Group by day (entries are sorted newest first).
    final groups = <DateTime, List<Object>>{};
    for (final e in entries) {
      final d = dateOfEntry(e);
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
    }
    // One row per day header and entry, built only when scrolled into view.
    final rows = <Object>[
      for (final group in groups.entries) ...[group, ...group.value],
    ];

    return Scaffold(
      appBar: AppBar(
        // The page's own scaffold sits below the app's, which has the menu.
        leading: const MenuButton(),
        title: PeriodSelector(period: state.period, onChanged: state.setPeriod),
        centerTitle: true,
        bottom: SelectedWalletChip.bottomFor(state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Root pages stay alive side by side in the bottom navigation;
        // shared hero tags would clash when a new screen opens.
        heroTag: null,
        icon: const Icon(Icons.add),
        label: Text(l.addRecord),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditRecordPage())),
      ),
      body: GestureDetector(
        // Swipe left/right to move to the previous or next period.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          state.shiftPeriod(v < 0 ? 1 : -1);
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: 1 + (rows.isEmpty ? 1 : rows.length),
          itemBuilder: (context, i) {
            if (i == 0) return _SummaryCard(state: state);
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(48),
                child: Center(child: Text(l.noRecordsInPeriod)),
              );
            }
            return switch (rows[i - 1]) {
              MapEntry<DateTime, List<Object>> g => _DayHeader(
                day: g.key,
                entries: g.value,
                state: state,
              ),
              final e => entryTile(e),
            };
          },
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
    // One wallet: a statement of money in and out, transfers included.
    // All wallets: real income and expenses (transfers cancel out).
    final income =
        state.periodIncome + state.periodTransfersIn + state.periodDebtIn;
    final expense =
        state.periodExpense + state.periodTransfersOut + state.periodDebtOut;
    final oneWallet = state.walletFilter != null;
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
                cell(
                  oneWallet ? l.moneyIn : l.income,
                  income,
                  Colors.green.shade600,
                ),
                cell(oneWallet ? l.moneyOut : l.expense, expense, scheme.error),
                cell(
                  l.net,
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
          switch (e) {
            Record r => state.signedAmount(r),
            Transfer t => _transferEffect(state, t),
            _ => _debtEffect(e as DebtEvent),
          },
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

class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});

  final Record record;

  @override
  Widget build(BuildContext context) {
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
    return ListTile(
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
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EditRecordPage(record: record))),
    );
  }
}

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final from = state.walletById(transfer.fromWalletId)?.name ?? '?';
    final to = state.walletById(transfer.toWalletId)?.name ?? '?';
    final effect = _transferEffect(state, transfer);
    return ListTile(
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
      // Without a filter, spell out what the transfer does to each wallet;
      // with one, the sign on the right says it. Each wallet's part is
      // kept on one line and wraps as a whole.
      subtitle: effect == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      '$from ${formatMoney(-transfer.amount, state.currency)}',
                      softWrap: false,
                    ),
                    Text(
                      '$to ${formatMoney(transfer.amount, state.currency, signed: true)}',
                      softWrap: false,
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                  ],
                ),
                if (transfer.note != null)
                  Text(
                    transfer.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          : Text(
              [
                l.transfer,
                if (transfer.note != null) transfer.note!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Text(
        effect == 0
            ? formatMoney(transfer.amount, state.currency)
            : formatMoney(effect, state.currency, signed: true),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: effect > 0
              ? Colors.green.shade600
              : effect < 0
              ? null
              : scheme.onSurfaceVariant,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditRecordPage(transfer: transfer)),
      ),
    );
  }
}

/// A debt being given or taken, or one of its repayments. Opens the debt.
class DebtEventTile extends StatelessWidget {
  const DebtEventTile({super.key, required this.event});

  final DebtEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final debt = event.debt;
    final what = event.isClosing
        ? (debt.lent ? l.closedUncollectedEvent : l.closedUnpaidEvent)
        : event.payment == null
        ? (debt.lent ? l.debtLentEvent : l.debtBorrowedEvent)
        : (debt.lent ? l.repaymentReceived : l.repaymentMade);
    final wallet = state.walletFilter == null
        ? state.walletById(event.walletId)
        : null;
    final effect = event.effect;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.tertiaryContainer,
        foregroundColor: scheme.onTertiaryContainer,
        child: const Icon(Icons.handshake_outlined),
      ),
      title: Text(debt.person, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [what, if (wallet != null) wallet.name].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatMoney(effect, state.currency, signed: true),
        // Only closing with money owed counts as income or expense; other
        // movements are shown muted.
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: !event.counts
              ? scheme.onSurfaceVariant
              : effect > 0
              ? Colors.green.shade600
              : scheme.error,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DebtDetailPage(debtId: debt.id!)),
      ),
    );
  }
}
