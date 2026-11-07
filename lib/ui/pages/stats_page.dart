import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
import '../widgets/month_selector.dart';

enum _Period { month, year }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.month;
  CategoryType _type = CategoryType.expense;
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month);
  List<Record> _records = [];
  int? _touched;
  AppState? _state;

  DateTime get _from => _period == _Period.month
      ? DateTime(_anchor.year, _anchor.month)
      : DateTime(_anchor.year);
  DateTime get _to => _period == _Period.month
      ? DateTime(_anchor.year, _anchor.month + 1)
      : DateTime(_anchor.year + 1);

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

  Future<void> _load() async {
    final records = await _state!.db.records(from: _from, to: _to);
    if (mounted) setState(() => _records = records);
  }

  void _update(VoidCallback fn) {
    setState(() {
      fn();
      _touched = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final byId = {for (final c in state.categories) c.id!: c};
    final totals = totalsByCategory(_records, byId, _type);
    final sum = totals.fold(0, (s, t) => s + t.total);

    final bucketCount = _period == _Period.month
        ? DateTime(_anchor.year, _anchor.month + 1, 0).day
        : 12;
    final buckets = bucketTotals(
      _records,
      byId,
      bucketCount,
      _period == _Period.month ? (d) => d.day - 1 : (d) => d.month - 1,
    );

    return Scaffold(
      appBar: AppBar(
        title: MonthSelector(
          month: _anchor,
          yearOnly: _period == _Period.year,
          onChanged: (m) => _update(() => _anchor = m),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_Period>(
                  segments: [
                    ButtonSegment(
                      value: _Period.month,
                      label: Text(l.periodMonth),
                    ),
                    ButtonSegment(
                      value: _Period.year,
                      label: Text(l.periodYear),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => _update(() => _period = s.first),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<CategoryType>(
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
                  onSelectionChanged: (s) => _update(() => _type = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totals.isEmpty)
            Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: Text(l.noDataForPeriod)),
            )
          else ...[
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 64,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, resp) {
                          if (!event.isInterestedForInteractions) return;
                          final i = resp?.touchedSection?.touchedSectionIndex;
                          setState(
                            () => _touched = (i == null || i < 0) ? null : i,
                          );
                        },
                      ),
                      sections: [
                        for (var i = 0; i < totals.length; i++)
                          PieChartSectionData(
                            value: totals[i].total.toDouble(),
                            color: totals[i].category.colorValue,
                            radius: i == _touched ? 46 : 38,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touched == null
                            ? l.total
                            : totals[_touched!].category.name,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        formatMoney(
                          _touched == null ? sum : totals[_touched!].total,
                          state.currency,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final t in totals)
              _CategoryRow(total: t, sum: sum, currency: state.currency),
          ],
          const SizedBox(height: 24),
          Text(
            _period == _Period.month ? l.daily : l.monthly,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _TrendChart(
              buckets: buckets,
              type: _type,
              labelOf: _period == _Period.month
                  ? (i) => '${i + 1}'
                  : (i) => DateFormat.MMM().format(DateTime(2000, i + 1)),
              labelEvery: _period == _Period.month ? 5 : 1,
              currency: state.currency,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.sum,
    required this.currency,
  });

  final CategoryTotal total;
  final int sum;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ratio = sum == 0 ? 0.0 : total.total / sum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CategoryAvatar(category: total.category, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${total.category.name} (${total.count})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(formatMoney(total.total, currency)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ratio,
                        color: total.category.colorValue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '%${(ratio * 100).toStringAsFixed(1)}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.buckets,
    required this.type,
    required this.labelOf,
    required this.labelEvery,
    required this.currency,
  });

  final List<(int, int)> buckets;
  final CategoryType type;
  final String Function(int) labelOf;
  final int labelEvery;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final (inc, exp) in buckets)
        (type == CategoryType.income ? inc : exp) / 100,
    ];
    final maxY = values.fold<double>(0, math.max);
    final color = type == CategoryType.income
        ? Colors.green.shade600
        : Theme.of(context).colorScheme.error;
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i % labelEvery != 0 && labelEvery > 1) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(labelOf(i), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${labelOf(group.x)}\n${formatMoney((rod.toY * 100).round(), currency)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: color,
                  width: values.length > 12 ? 6 : 14,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
