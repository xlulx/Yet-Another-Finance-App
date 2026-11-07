import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/recurring_rule.dart';
import '../../services/recurrence.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import 'edit_recurring_page.dart';

String describeInterval(RecurringRule r) {
  const names = {
    RecurrenceUnit.day: 'gün',
    RecurrenceUnit.week: 'hafta',
    RecurrenceUnit.month: 'ay',
    RecurrenceUnit.year: 'yıl',
  };
  const single = {
    RecurrenceUnit.day: 'Her gün',
    RecurrenceUnit.week: 'Her hafta',
    RecurrenceUnit.month: 'Her ay',
    RecurrenceUnit.year: 'Her yıl',
  };
  return r.interval == 1
      ? single[r.unit]!
      : 'Her ${r.interval} ${names[r.unit]}';
}

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tekrarlayan işlemler')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ekle',
        child: const Icon(Icons.add),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditRecurringPage())),
      ),
      body: state.rules.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Kira, maaş, abonelik gibi düzenli işlemleri ekleyin; '
                  'zamanı gelince otomatik kaydedilsin.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final r in state.rules) _RuleTile(rule: r, state: state),
              ],
            ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.state});

  final RecurringRule rule;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final category = state.categoryById(rule.categoryId);
    final next = nextOccurrence(rule);
    final income = category?.type == CategoryType.income;
    return ListTile(
      leading: CategoryAvatar(category: category),
      title: Text(rule.title.isNotEmpty ? rule.title : (category?.name ?? '?')),
      subtitle: Text(
        [
          describeInterval(rule),
          next == null
              ? 'Bitti'
              : 'Sonraki: ${DateFormat('d MMM y', 'tr_TR').format(next)}',
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
