import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/record.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import '../widgets/month_selector.dart';
import 'edit_record_page.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final records = state.monthRecords;

    // Group by day (records are already sorted newest first).
    final groups = <DateTime, List<Record>>{};
    for (final r in records) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      groups.putIfAbsent(day, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: MonthSelector(month: state.month, onChanged: state.setMonth),
        centerTitle: true,
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
            if (records.isEmpty)
              Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: Text(l.noRecordsThisMonth)),
              ),
            for (final entry in groups.entries) ...[
              _DayHeader(day: entry.key, records: entry.value, state: state),
              for (final r in entry.value) _RecordTile(record: r),
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
    Widget cell(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatMoney(value, state.currency),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
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
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.records,
    required this.state,
  });

  final DateTime day;
  final List<Record> records;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final total = records.fold(0, (s, r) => s + state.signedAmount(r));
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
    return Dismissible(
      key: ValueKey('record-${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await state.deleteRecord(record);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.recordDeleted),
            action: SnackBarAction(
              label: l.undo,
              onPressed: () => state.restoreRecord(record),
            ),
          ),
        );
      },
      child: ListTile(
        leading: CategoryAvatar(category: category),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (record.title.isNotEmpty && category != null) category.name,
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
