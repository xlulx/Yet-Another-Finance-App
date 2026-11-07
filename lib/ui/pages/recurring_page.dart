import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../models/category.dart';
import '../../models/recurring_rule.dart';
import '../../services/recurrence.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import 'edit_recurring_page.dart';

String describeInterval(AppLocalizations l, RecurringRule r) {
  if (r.interval == 1) {
    return switch (r.unit) {
      RecurrenceUnit.day => l.everyDay,
      RecurrenceUnit.week => l.everyWeek,
      RecurrenceUnit.month => l.everyMonth,
      RecurrenceUnit.year => l.everyYear,
    };
  }
  return l.everyN(r.interval, unitName(l, r.unit, r.interval));
}

String unitName(AppLocalizations l, RecurrenceUnit unit, int count) =>
    switch (unit) {
      RecurrenceUnit.day => l.unitDay(count),
      RecurrenceUnit.week => l.unitWeek(count),
      RecurrenceUnit.month => l.unitMonth(count),
      RecurrenceUnit.year => l.unitYear(count),
    };

/// Recurring transactions list; one tab of [ManagePage].
class RecurringTab extends StatelessWidget {
  const RecurringTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    if (state.rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.recurringEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [for (final r in state.rules) _RuleTile(rule: r, state: state)],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.state});

  final RecurringRule rule;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final category = state.categoryById(rule.categoryId);
    final next = nextOccurrence(rule);
    final income = category?.type == CategoryType.income;
    return ListTile(
      leading: CategoryAvatar(category: category),
      title: Text(rule.title.isNotEmpty ? rule.title : (category?.name ?? '?')),
      subtitle: Text(
        [
          describeInterval(l, rule),
          next == null ? l.finished : l.nextOn(DateFormat.yMMMd().format(next)),
        ].join(' · '),
      ),
      trailing: Text(
        formatMoney(income ? rule.amount : -rule.amount, state.currency),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: income ? Colors.green.shade600 : null,
        ),
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EditRecurringPage(rule: rule))),
    );
  }
}
