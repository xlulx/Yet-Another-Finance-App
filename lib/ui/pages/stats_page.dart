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
import 'records_page.dart';

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

  /// Net: income and expense bars side by side instead of the net.
  bool _netSplit = false;

  /// Net: a line of the running total over the bars.
  bool _cumulative = false;

  /// The bar picked in the bar chart; its entries are listed below.
  int? _selected;

  /// What the selection belongs to; another period or filter clears it.
  Object? _selectionKey;

  void _set(VoidCallback fn) => setState(() {
    fn();
    _touched = null;
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final byId = {for (final c in state.categories) c.id!: c};
    final wallet = state.walletFilter;
    final period = state.period;
    final range = StatsRange(period.from, period.to);
    final key = (period, wallet);
    if (key != _selectionKey) {
      _selectionKey = key;
      _selected = null;
    }

    final buckets = bucketTotals(
      state.periodRecords,
      byId,
      range.bucketCount,
      range.bucketOf,
      transfers: state.periodTransfers,
      walletId: wallet,
      debtEvents: state.periodDebtEvents,
    );
    final values = [
      for (final (inc, exp) in buckets)
        switch (_view) {
          _View.expense => exp,
          _View.income => inc,
          _View.net => inc - exp,
        },
    ];
    final total = values.fold(0, (s, v) => s + v);
    // Averaged over the days, weeks or months so far, not future ones.
    final today = DateTime.now();
    var elapsed = 0;
    for (var i = 0; i < range.bucketCount; i++) {
      if (!range.bucketStart(i).isAfter(today)) elapsed++;
    }
    final average = (total / (elapsed == 0 ? 1 : elapsed)).round();

    final bars = _chart == _Chart.bars || _view == _View.net;
    final split = _view == _View.net && _netSplit;
    // The net added up bucket by bucket, up to today.
    final running = <int>[];
    for (var i = 0, sum = 0; i < elapsed; i++) {
      sum += buckets[i].$1 - buckets[i].$2;
      running.add(sum);
    }
    final selected = bars ? _selected : null;
    final scheme = theme.colorScheme;
    final color = switch (_view) {
      _View.expense => scheme.error,
      _View.income => Colors.green.shade600,
      _View.net => total < 0 ? scheme.error : scheme.primary,
    };

    List<CategoryTotal> totalsOf(CategoryType type) =>
        _categoryTotals(l, state, byId, type);
    final type = _view == _View.income
        ? CategoryType.income
        : CategoryType.expense;
    final totals = _view == _View.net ? <CategoryTotal>[] : totalsOf(type);

    /// Below the chart: the categories, or the picked bar's entries.
    List<Widget> section(CategoryType type, List<CategoryTotal> totals) {
      if (selected != null) {
        final entries = _bucketEntries(state, range, selected, type);
        if (entries.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.nothingOnDate),
            ),
          ];
        }
        return [for (final e in entries) entryTile(e)];
      }
      final sum = totals.fold(0, (s, t) => s + t.total);
      return [
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
      ];
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

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
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_View>(
              // The check mark makes the labels wrap on phones.
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _View.expense, label: Text(l.expense)),
                ButtonSegment(value: _View.income, label: Text(l.income)),
                ButtonSegment(value: _View.net, label: Text(l.net)),
              ],
              selected: {_view},
              onSelectionChanged: (s) => _set(() => _view = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(
                          total,
                          state.currency,
                          signed: _view == _View.net,
                        ),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      switch (range.unit) {
                        BucketUnit.day => l.averagePerDay,
                        BucketUnit.week => l.averagePerWeek,
                        BucketUnit.month => l.averagePerMonth,
                      }(formatMoney(average, state.currency)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_view == _View.net) ...[
                IconButton.filledTonal(
                  iconSize: 26,
                  padding: const EdgeInsets.all(12),
                  tooltip: _netSplit ? l.showNet : l.showIncomeAndExpense,
                  icon: Icon(
                    _netSplit
                        ? Icons.account_balance_wallet
                        : Icons.compare_arrows,
                  ),
                  onPressed: () => setState(() => _netSplit = !_netSplit),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  iconSize: 26,
                  padding: const EdgeInsets.all(12),
                  tooltip: _cumulative
                      ? l.hideRunningTotal
                      : l.showRunningTotal,
                  icon: Icon(_cumulative ? Icons.remove : Icons.trending_up),
                  onPressed: () => setState(() => _cumulative = !_cumulative),
                ),
              ],
              // The net is only shown as bars.
              if (_view != _View.net)
                IconButton.filledTonal(
                  iconSize: 28,
                  padding: const EdgeInsets.all(14),
                  tooltip: bars ? l.pieChart : l.barChart,
                  icon: Icon(bars ? Icons.pie_chart : Icons.bar_chart),
                  onPressed: () =>
                      _set(() => _chart = bars ? _Chart.pie : _Chart.bars),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!bars && totals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(child: Text(l.noDataForPeriod)),
            )
          else if (!bars)
            _Pie(
              totals: totals,
              touched: _touched,
              onTouched: (i) => setState(() => _touched = i),
              currency: state.currency,
            )
          else
            SizedBox(
              height: 240,
              child: TrendChart(
                values: split ? [for (final b in buckets) b.$1] : values,
                values2: split ? [for (final b in buckets) b.$2] : null,
                color: split
                    ? Colors.green.shade600
                    : (_view == _View.net ? null : color),
                color2: scheme.error,
                signed: _view == _View.net && !split,
                // The average of the net; not of income and expenses apart.
                average: split ? null : average,
                line: _view == _View.net && _cumulative ? running : null,
                selected: selected,
                onSelected: (i) => setState(() => _selected = i),
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
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bucketLabel(range, selected, long: true),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(l.clearSelection),
                    onPressed: () => setState(() => _selected = null),
                  ),
                ],
              ),
            ),
          if (_view == _View.net) ...[
            heading(l.income),
            ...section(CategoryType.income, totalsOf(CategoryType.income)),
            heading(l.expense),
            ...section(CategoryType.expense, totalsOf(CategoryType.expense)),
          ] else ...[
            const SizedBox(height: 12),
            ...section(type, totals),
          ],
        ],
      ),
    );
  }

  /// Records, transfers and written-off debts in bar [i] on the [type]
  /// side, newest first.
  List<Object> _bucketEntries(
    AppState state,
    StatsRange range,
    int i,
    CategoryType type,
  ) {
    final income = type == CategoryType.income;
    final wallet = state.walletFilter;
    bool inBar(DateTime d) => range.bucketOf(d) == i;
    return <Object>[
      for (final r in state.periodRecords)
        if (inBar(r.date) && state.isIncome(r) == income) r,
      // Transfers only count when looking at one wallet.
      if (wallet != null)
        for (final t in state.periodTransfers)
          if (inBar(t.date) &&
              (income ? t.toWalletId == wallet : t.fromWalletId == wallet))
            t,
      for (final e in state.periodDebtEvents)
        if (e.counts && inBar(e.date) && (e.effect > 0) == income) e,
    ]..sort((a, b) => dateOfEntry(b).compareTo(dateOfEntry(a)));
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
/// month; [short] for the axis, [long] for a heading.
String bucketLabel(
  StatsRange range,
  int i, {
  bool short = false,
  bool long = false,
}) {
  final start = range.bucketStart(i);
  switch (range.unit) {
    case BucketUnit.day:
      if (long) return DateFormat.yMMMMEEEEd().format(start);
      return short ? '${start.day}' : DateFormat.MMMd().format(start);
    case BucketUnit.week:
      if (long) {
        final end = DateTime(start.year, start.month, start.day + 6);
        return '${DateFormat.MMMd().format(start)} – '
            '${DateFormat.yMMMd().format(end)}';
      }
      return short
          ? DateFormat.Md().format(start)
          : DateFormat.MMMd().format(start);
    case BucketUnit.month:
      if (long) {
        return toBeginningOfSentenceCase(DateFormat.yMMMM().format(start));
      }
      return short
          ? DateFormat.MMM().format(start)
          : DateFormat.yMMM().format(start);
  }
}

/// Categories as a ring, with the largest ones and their shares beside
/// it; touch a slice to see its amount in the middle.
class _Pie extends StatelessWidget {
  const _Pie({
    required this.totals,
    required this.touched,
    required this.onTouched,
    required this.currency,
  });

  final List<CategoryTotal> totals;
  final int? touched;
  final ValueChanged<int?> onTouched;
  final String currency;

  /// Legend entries; the rest are in the list below.
  static const _legendSize = 6;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sum = totals.fold(0, (s, t) => s + t.total);
    final t = touched == null ? null : totals[touched!];
    final percent = NumberFormat.decimalPercentPattern(decimalDigits: 1);
    return SizedBox(
      height: 190,
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
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
                          radius: i == touched ? 40 : 34,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                if (t != null)
                  SizedBox(
                    width: 80,
                    child: FittedBox(
                      child: Text(
                        formatMoney(t.total, currency),
                        style: text.labelLarge,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in totals.take(_legendSize))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundColor: c.category.colorValue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium,
                          ),
                        ),
                        Text(
                          percent.format(sum == 0 ? 0 : c.total / sum),
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
/// is null. [signed] amounts (the net) may go below zero. Amounts on the
/// left, an [average] line, and a bar can be picked with [onSelected].
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
    this.average,
    this.selected,
    this.onSelected,
    this.values2,
    this.color2,
    this.line,
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

  /// Drawn as a labelled line, in minor units.
  final int? average;

  /// The picked bar; the others are dimmed.
  final int? selected;

  /// Called with the tapped bar, or null when it was already picked.
  final ValueChanged<int?>? onSelected;

  /// A second bar per bucket, next to the first, in [color2].
  final List<int>? values2;
  final Color? color2;

  /// A line over the bars (e.g. the running total), in minor units; may
  /// stop before the last bucket.
  final List<int>? line;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final all = [...values, ...?values2, ...?line];
    final maxV = all.fold<double>(0, (m, v) => math.max(m, v / 100));
    final minV = all.fold<double>(0, (m, v) => math.min(m, v / 100));
    final span = maxV - minV == 0 ? 1.0 : maxV - minV;
    final step = _niceStep(span / 4);
    final maxY = maxV <= 0 ? 0.0 : (maxV / step).ceil() * step;
    final minY = minV >= 0 ? 0.0 : (minV / step).floor() * step;
    final pair = values2 != null;
    final width = values.length > 16 ? (pair ? 3.0 : 6.0) : (pair ? 8.0 : 14.0);
    final top = maxY == minY ? 1.0 : maxY;
    final axis = NumberFormat.compact(locale: Intl.getCurrentLocale());
    final lineColor = scheme.outlineVariant;
    BarChartRodData rod(int cents, Color c, int i) => BarChartRodData(
      toY: cents / 100,
      color: c.withValues(alpha: selected == null || selected == i ? 1 : 0.35),
      width: width,
      borderRadius: BorderRadius.circular(3),
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        fromY: minY,
        toY: top,
        color: Colors.transparent,
      ),
    );
    final chart = BarChart(
      BarChartData(
        // Bar centres at (i + 0.5) / n of the width, like the line's points.
        alignment: BarChartAlignment.spaceAround,
        maxY: top,
        minY: minY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: lineColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: average == null || average == 0
            ? null
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: average! / 100,
                    color: scheme.onSurface,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      labelResolver: (_) => l.average,
                    ),
                  ),
                ],
              ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: step,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  axis.format(v),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
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
          // The whole column can be tapped, not only the bar: small bars
          // would be hard to hit.
          allowTouchBarBackDraw: true,
          touchCallback: onSelected == null
              ? null
              : (event, resp) {
                  if (event is! FlTapUpEvent) return;
                  final i = resp?.spot?.touchedBarGroupIndex;
                  if (i == null) return;
                  onSelected!(i == selected ? null : i);
                },
          touchTooltipData: BarTouchTooltipData(
            // Plain light text on a dark bubble: easy to read.
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${labelOf(group.x)}\n'
              '${pair ? (rodIndex == 0 ? '${l.income}: ' : '${l.expense}: ') : ''}'
              '${formatMoney((rod.toY * 100).round(), currency, signed: signed)}',
              TextStyle(color: scheme.onInverseSurface, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                rod(
                  values[i],
                  color ??
                      (values[i] < 0 ? scheme.error : Colors.green.shade600),
                  i,
                ),
                if (pair) rod(values2![i], color2 ?? scheme.error, i),
              ],
            ),
        ],
      ),
    );
    if (line == null) return chart;
    final lineColor2 = scheme.primary;
    // Drawn over the bars with the same scale and margins; touches go
    // through to the bars.
    return Stack(
      children: [
        chart,
        IgnorePointer(
          child: LineChart(
            LineChartData(
              minX: -0.5,
              maxX: values.length - 0.5,
              minY: minY,
              maxY: top,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < line!.length; i++)
                      FlSpot(i.toDouble(), line![i] / 100),
                  ],
                  color: lineColor2,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  // Filled between the line and zero, above or below it.
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor2.withValues(alpha: 0.12),
                    cutOffY: 0,
                    applyCutOffY: true,
                  ),
                  aboveBarData: BarAreaData(
                    show: true,
                    color: lineColor2.withValues(alpha: 0.12),
                    cutOffY: 0,
                    applyCutOffY: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A round step for the grid: 1, 2 or 5 times a power of ten.
  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (raw <= m * p) return m * p;
    }
    return 10 * p;
  }
}
