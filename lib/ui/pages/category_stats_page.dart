import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/record.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import 'edit_record_page.dart';
import 'stats_page.dart';

/// One category in statistics: its total and records for the period
/// [from] up to [to] (exclusive), and the last 12 months up to then.
class CategoryStatsPage extends StatefulWidget {
  const CategoryStatsPage({
    super.key,
    required this.category,
    required this.from,
    required this.to,
  });

  final Category category;
  final DateTime from;
  final DateTime to;

  @override
  State<CategoryStatsPage> createState() => _CategoryStatsPageState();
}

class _CategoryStatsPageState extends State<CategoryStatsPage> {
  late final StatsRange _year;
  List<Record> _records = [];
  List<(int, int)> _months = [];
  AppState? _state;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    final last = widget.to.subtract(const Duration(days: 1));
    _year = StatsRange(
      DateTime(last.year, last.month - 11),
      DateTime(last.year, last.month + 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (_state != state) {
      _state?.removeListener(_load);
      _state = state..addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_load);
    super.dispose();
  }

  /// Reloads on every change, so edits made from here show up.
  Future<void> _load() async {
    final id = ++_loadId;
    final state = _state!;
    final from = widget.from.isBefore(_year.from) ? widget.from : _year.from;
    final to = widget.to.isAfter(_year.to) ? widget.to : _year.to;
    final all = [
      for (final r in await state.db.records(
        from: from,
        to: to,
        walletId: state.walletFilter,
      ))
        if (r.categoryId == widget.category.id) r,
    ];
    final months = List.filled(_year.bucketCount, 0);
    for (final r in all) {
      final i = _year.bucketOf(r.date);
      if (i >= 0 && i < months.length) months[i] += r.amount;
    }
    if (!mounted || id != _loadId) return;
    setState(() {
      _records = [
        for (final r in all)
          if (!r.date.isBefore(widget.from) && r.date.isBefore(widget.to)) r,
      ];
      // TrendChart takes (income, expense) pairs; one series is enough.
      _months = [for (final m in months) (0, m)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final c = state.categoryById(widget.category.id!) ?? widget.category;
    final income = c.type == CategoryType.income;
    final total = _records.fold(0, (s, r) => s + r.amount);
    final last = widget.to.subtract(const Duration(days: 1));
    final period =
        '${DateFormat.yMMMd().format(widget.from)} – '
        '${DateFormat.yMMMd().format(last)}';
    final day = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CategoryAvatar(category: c, radius: 16),
            const SizedBox(width: 12),
            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(period, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(
                    formatMoney(total, state.currency),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: income
                          ? Colors.green.shade600
                          : theme.colorScheme.error,
                    ),
                  ),
                  Text(
                    l.recordCount(_records.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.last12Months, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 180,
              child: TrendChart(
                buckets: _months,
                labelOf: (i) => bucketLabel(_year, i),
                shortLabelOf: (i) => bucketLabel(_year, i, short: true),
                labelEvery: 2,
                labelFromEnd: true,
                currency: state.currency,
                single: c.colorValue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(l.navRecords, style: theme.textTheme.titleSmall),
          ),
          if (_records.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.categoryEmpty),
            ),
          for (final r in _records)
            ListTile(
              title: Text(
                r.title.isNotEmpty ? r.title : c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  day.format(r.date),
                  if (state.walletFilter == null &&
                      state.wallets.length > 1 &&
                      state.walletById(r.walletId) != null)
                    state.walletById(r.walletId)!.name,
                  if (r.note != null) r.note!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formatMoney(income ? r.amount : -r.amount, state.currency),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: income ? Colors.green.shade600 : null,
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditRecordPage(record: r)),
              ),
            ),
        ],
      ),
    );
  }
}
