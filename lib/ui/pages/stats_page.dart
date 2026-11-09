import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../../utils/category_icons.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import '../widgets/menu_button.dart';
import '../widgets/period_selector.dart';
import '../widgets/selected_wallet_chip.dart';
import 'category_stats_page.dart';

/// What the page shows: expenses or income by category, or the net.
enum _View { expense, income, net }

enum _Chart { pie, bars }

/// Statistics for the period chosen at the top, shared with the records
/// page (and the same wallet filter).
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _View _view = _View.expense;
  _Chart _chart = _Chart.pie;
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final byId = {for (final c in state.categories) c.id!: c};
    final wallet = state.walletFilter;
    final period = state.period;
    final range = StatsRange(period.from, period.to);
    final debtEvents = state.periodDebtEvents;

    final buckets = bucketTotals(
      state.periodRecords,
      byId,
      range.bucketCount,
      range.bucketOf,
      transfers: state.periodTransfers,
      walletId: wallet,
      debtEvents: debtEvents,
    );
    final income = buckets.fold(0, (s, b) => s + b.$1);
    final expense = buckets.fold(0, (s, b) => s + b.$2);

    // Expenses or income by category; the net has none.
    final type = _view == _View.income
        ? CategoryType.income
        : CategoryType.expense;
    final totals = _view == _View.net
        ? <CategoryTotal>[]
        : _categoryTotals(l, state, byId, type);
    final sum = totals.fold(0, (s, t) => s + t.total);
    final pie = _chart == _Chart.pie && _view != _View.net;

    return Scaffold(
      appBar: AppBar(
        // The page's own scaffold sits below the app's, which has the menu.
        leading: const MenuButton(),
        title: PeriodSelector(period: period, onChanged: state.setPeriod),
        centerTitle: true,
        bottom: SelectedWalletChip.bottomFor(state),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_View>(
                  // The check mark makes the labels wrap on phones.
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: _View.expense, label: Text(l.expense)),
                    ButtonSegment(value: _View.income, label: Text(l.income)),
                    ButtonSegment(value: _View.net, label: Text(l.net)),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() {
                    _view = s.first;
                    _touched = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<_Chart>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Chart.pie,
                    tooltip: l.pieChart,
                    icon: const Icon(Icons.pie_chart_outline),
                    // The net has no categories to slice.
                    enabled: _view != _View.net,
                  ),
                  ButtonSegment(
                    value: _Chart.bars,
                    tooltip: l.barChart,
                    icon: const Icon(Icons.bar_chart),
                  ),
                ],
                selected: {_view == _View.net ? _Chart.bars : _chart},
                onSelectionChanged: (s) => setState(() {
                  _chart = s.first;
                  _touched = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Summary(
            income: income,
            expense: expense,
            oneWallet: wallet != null,
            currency: state.currency,
          ),
          const SizedBox(height: 16),
          if (pie && totals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(child: Text(l.noDataForPeriod)),
            )
          else if (pie)
            _Pie(
              totals: totals,
              sum: sum,
              touched: _touched,
              onTouched: (i) => setState(() => _touched = i),
              currency: state.currency,
            )
          else ...[
            Text(switch (range.unit) {
              BucketUnit.day => l.daily,
              BucketUnit.week => l.weekly,
              BucketUnit.month => l.monthly,
            }, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: TrendChart(
                values: [
                  for (final (inc, exp) in buckets)
                    switch (_view) {
                      _View.expense => exp,
                      _View.income => inc,
                      _View.net => inc - exp,
                    },
                ],
                // The net is green or red by its sign.
                color: switch (_view) {
                  _View.expense => theme.colorScheme.error,
                  _View.income => Colors.green.shade600,
                  _View.net => null,
                },
                signed: _view == _View.net,
                labelOf: (i) => bucketLabel(range, i),
                shortLabelOf: (i) => bucketLabel(range, i, short: true),
                labelEvery: range.bucketCount > 16
                    ? 5
                    : range.bucketCount > 8
                    ? 2
                    : 1,
                currency: state.currency,
              ),
            ),
          ],
          if (totals.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final t in totals)
              _CategoryRow(
                total: t,
                sum: sum,
                currency: state.currency,
                onTap: t.category.id == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryStatsPage(
                            category: t.category,
                            from: period.from,
                            to: period.to,
                          ),
                        ),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  /// Totals per category, plus, with a wallet filter, transfers per other
  /// wallet, and debts closed with money still owed per person; largest
  /// first.
  List<CategoryTotal> _categoryTotals(
    AppLocalizations l,
    AppState state,
    Map<int, Category> byId,
    CategoryType type,
  ) {
    final totals = totalsByCategory(state.periodRecords, byId, type);
    final wallet = state.walletFilter;
    if (wallet != null) {
      for (final (other, total, count) in transferTotals(
        state.periodTransfers,
        wallet,
        type,
      )) {
        final w = state.walletById(other);
        final name = w?.name ?? '?';
        totals.add(
          CategoryTotal(
            Category(
              name: type == CategoryType.expense
                  ? l.transferToWallet(name)
                  : l.transferFromWallet(name),
              type: type,
              color: w?.color ?? 0xFF9E9E9E,
              icon: transferIconKey,
            ),
            total,
            count,
          ),
        );
      }
    }
    for (final (person, total, count) in debtTotals(
      state.periodDebtEvents,
      type,
    )) {
      final hash = person.toLowerCase().codeUnits.fold(0, (h, c) => h + c);
      totals.add(
        CategoryTotal(
          Category(
            name: l.debtSlice(person),
            type: type,
            color: categoryColors[hash % categoryColors.length],
            icon: debtIconKey,
          ),
          total,
          count,
        ),
      );
    }
    return totals..sort((a, b) => b.total.compareTo(a.total));
  }
}

/// A bucket's name for the chart: the day, the week's first day or the
/// month; [short] for the axis.
String bucketLabel(StatsRange range, int i, {bool short = false}) {
  final start = range.bucketStart(i);
  return switch (range.unit) {
    BucketUnit.day => short ? '${start.day}' : DateFormat.MMMd().format(start),
    BucketUnit.week =>
      short ? DateFormat.Md().format(start) : DateFormat.MMMd().format(start),
    BucketUnit.month =>
      short ? DateFormat.MMM().format(start) : DateFormat.yMMM().format(start),
  };
}

/// Income, expenses and what is left.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.income,
    required this.expense,
    required this.oneWallet,
    required this.currency,
  });

  final int income;
  final int expense;

  /// One wallet: money in and out, like a statement.
  final bool oneWallet;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final net = income - expense;
    Widget cell(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatMoney(value, currency),
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            cell(
              oneWallet ? l.moneyIn : l.income,
              income,
              Colors.green.shade600,
            ),
            cell(oneWallet ? l.moneyOut : l.expense, expense, scheme.error),
            cell(l.net, net, net >= 0 ? scheme.primary : scheme.error),
          ],
        ),
      ),
    );
  }
}

/// Categories as slices; touch one to see its share in the middle.
class _Pie extends StatelessWidget {
  const _Pie({
    required this.totals,
    required this.sum,
    required this.touched,
    required this.onTouched,
    required this.currency,
  });

  final List<CategoryTotal> totals;
  final int sum;
  final int? touched;
  final ValueChanged<int?> onTouched;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final t = touched == null ? null : totals[touched!];
    return SizedBox(
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
                  onTouched((i == null || i < 0) ? null : i);
                },
              ),
              sections: [
                for (var i = 0; i < totals.length; i++)
                  PieChartSectionData(
                    value: totals[i].total.toDouble(),
                    color: totals[i].category.colorValue,
                    radius: i == touched ? 46 : 38,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t?.category.name ?? l.total, style: text.labelMedium),
              Text(
                formatMoney(t?.total ?? sum, currency),
                style: text.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A category's name, amount and share of the total; tap to open it.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.sum,
    required this.currency,
    this.onTap,
  });

  final CategoryTotal total;
  final int sum;
  final String currency;

  /// Opens the category's details; null for transfer and debt slices.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = sum == 0 ? 0.0 : total.total / sum;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
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
                          total.category.name,
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
                          NumberFormat.decimalPercentPattern(decimalDigits: 1)
                              .format(ratio),
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
      ),
    );
  }
}

/// One bar per bucket, in [color], or green and red by sign when [color]
/// is null. [signed] amounts (the net) may go below zero.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.labelOf,
    required this.shortLabelOf,
    required this.labelEvery,
    required this.currency,
    this.color,
    this.signed = false,
    this.labelFromEnd = false,
  });

  /// Amounts in minor units.
  final List<int> values;
  final String Function(int) labelOf;
  final String Function(int) shortLabelOf;
  final int labelEvery;
  final String currency;
  final Color? color;
  final bool signed;

  /// Count [labelEvery] back from the last bar, so the latest is labelled.
  final bool labelFromEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = values.fold<double>(0, (m, v) => math.max(m, v / 100));
    final minY = values.fold<double>(0, (m, v) => math.min(m, v / 100));
    final width = values.length > 16 ? 6.0 : 14.0;
    return BarChart(
      BarChartData(
        maxY: maxY == 0 && minY == 0 ? 1 : maxY * 1.15,
        minY: minY * 1.15,
        gridData: FlGridData(
          show: minY < 0,
          drawVerticalLine: false,
          // Only the zero line, when bars go below it.
          checkToShowHorizontalLine: (v) => v == 0,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
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
                final n = labelFromEnd ? values.length - 1 - i : i;
                if (n % labelEvery != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    shortLabelOf(i),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // Plain light text on a dark bubble: easy to read.
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${labelOf(group.x)}\n'
              '${formatMoney((rod.toY * 100).round(), currency, signed: signed)}',
              TextStyle(color: scheme.onInverseSurface, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i] / 100,
                  color:
                      color ??
                      (values[i] < 0 ? scheme.error : Colors.green.shade600),
                  width: width,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
