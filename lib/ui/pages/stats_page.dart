import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/debt.dart';
import '../../models/record.dart';
import '../../models/transfer.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../../utils/category_icons.dart';
import '../../utils/money.dart';
import '../widgets/category_avatar.dart';
import '../widgets/menu_button.dart';
import '../widgets/month_selector.dart';
import '../widgets/selected_wallet_chip.dart';
import 'category_stats_page.dart';
import 'debts_page.dart';

enum _Period { month, year, last3Months, last12Months, custom }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.active = true});

  /// Whether the page is on screen. It stays alive in the bottom
  /// navigation; while hidden, changes are only loaded once it is shown.
  final bool active;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.month;
  CategoryType _type = CategoryType.expense;
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month);

  /// The chosen dates for [_Period.custom], both included.
  DateTimeRange? _custom;
  List<Record> _records = [];
  List<Transfer> _transfers = [];
  int? _touched;
  AppState? _state;

  /// Data changed while the page was hidden.
  bool _stale = false;

  /// Bumped per load, so a slow earlier load cannot overwrite a newer one.
  int _loadId = 0;

  StatsRange get _range {
    final now = DateTime.now();
    return switch (_period) {
      _Period.month => StatsRange(
        _anchor,
        DateTime(_anchor.year, _anchor.month + 1),
      ),
      _Period.year => StatsRange(
        DateTime(_anchor.year),
        DateTime(_anchor.year + 1),
      ),
      // Ending with the current month.
      _Period.last3Months => StatsRange(
        DateTime(now.year, now.month - 2),
        DateTime(now.year, now.month + 1),
      ),
      _Period.last12Months => StatsRange(
        DateTime(now.year, now.month - 11),
        DateTime(now.year, now.month + 1),
      ),
      _Period.custom => StatsRange(
        _custom!.start,
        _custom!.end.add(const Duration(days: 1)),
      ),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (_state != state) {
      _state?.removeListener(_onStateChanged);
      _state = state..addListener(_onStateChanged);
      _onStateChanged();
    }
  }

  @override
  void didUpdateWidget(StatsPage old) {
    super.didUpdateWidget(old);
    if (widget.active && _stale) _load();
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (widget.active) {
      _load();
    } else {
      _stale = true;
    }
  }

  Future<void> _load() async {
    _stale = false;
    final id = ++_loadId;
    final wallet = _state!.walletFilter;
    final range = _range;
    final records = await _state!.db.records(
      from: range.from,
      to: range.to,
      walletId: wallet,
    );
    // Like a bank statement, one wallet's statistics include its transfers.
    // Across all wallets they cancel out and are left out.
    final transfers = wallet == null
        ? <Transfer>[]
        : await _state!.db.transfers(
            from: range.from,
            to: range.to,
            walletId: wallet,
          );
    if (mounted && id == _loadId) {
      setState(() {
        _records = records;
        _transfers = transfers;
      });
    }
  }

  void _update(VoidCallback fn) {
    setState(() {
      fn();
      _touched = null;
    });
    _load();
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      initialDateRange:
          _custom ??
          DateTimeRange(start: DateTime(now.year, now.month - 1), end: now),
    );
    if (picked != null) {
      _update(() {
        _custom = picked;
        _period = _Period.custom;
      });
    }
  }

  void _choosePeriod(_Period p) {
    if (p == _Period.custom) {
      _pickCustom();
    } else {
      _update(() => _period = p);
    }
  }

  String _periodName(AppLocalizations l, _Period p) => switch (p) {
    _Period.month => l.periodMonth,
    _Period.year => l.periodYear,
    _Period.last3Months => l.periodLast3Months,
    _Period.last12Months => l.periodLast12Months,
    _Period.custom => l.periodCustom,
  };

  /// The app bar title: arrows for a month or year, the dates otherwise.
  Widget _title(StatsRange range) {
    if (_period == _Period.month || _period == _Period.year) {
      return MonthSelector(
        month: _anchor,
        yearOnly: _period == _Period.year,
        onChanged: (m) => _update(() => _anchor = m),
      );
    }
    final last = range.to.subtract(const Duration(days: 1));
    final text = _period == _Period.custom
        ? '${DateFormat.yMMMd().format(range.from)} – '
              '${DateFormat.yMMMd().format(last)}'
        : '${DateFormat.yMMM().format(range.from)} – '
              '${DateFormat.yMMM().format(last)}';
    final label = Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    );
    if (_period != _Period.custom) return label;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _pickCustom,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: label),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final byId = {for (final c in state.categories) c.id!: c};
    final wallet = state.walletFilter;
    final range = _range;
    // Debt movements in the period that touched a wallet (the filtered one,
    // if any).
    final debtEvents = [
      for (final e in state.allDebtEvents())
        if (!e.date.isBefore(range.from) &&
            e.date.isBefore(range.to) &&
            (e.walletId != null || (e.isClosing && wallet == null)) &&
            (wallet == null || e.walletId == wallet))
          e,
    ];
    final totals = totalsByCategory(_records, byId, _type);
    if (wallet != null) {
      // One slice per other wallet, shown like a category.
      for (final (other, total, count) in transferTotals(
        _transfers,
        wallet,
        _type,
      )) {
        final w = state.walletById(other);
        final name = w?.name ?? '?';
        totals.add(
          CategoryTotal(
            Category(
              name: _type == CategoryType.expense
                  ? l.transferToWallet(name)
                  : l.transferFromWallet(name),
              type: _type,
              color: w?.color ?? 0xFF9E9E9E,
              icon: transferIconKey,
            ),
            total,
            count,
          ),
        );
      }
    }
    // Debts closed with money still owed: a loss or gain, one slice per
    // person. Other debt movements are not income or expense.
    for (final (person, total, count) in debtTotals(debtEvents, _type)) {
      final hash = person.toLowerCase().codeUnits.fold(0, (h, c) => h + c);
      totals.add(
        CategoryTotal(
          Category(
            name: l.debtSlice(person),
            type: _type,
            color: categoryColors[hash % categoryColors.length],
            icon: debtIconKey,
          ),
          total,
          count,
        ),
      );
    }
    totals.sort((a, b) => b.total.compareTo(a.total));
    final sum = totals.fold(0, (s, t) => s + t.total);

    final buckets = bucketTotals(
      _records,
      byId,
      range.bucketCount,
      range.bucketOf,
      transfers: _transfers,
      walletId: wallet,
      debtEvents: debtEvents,
    );
    final income = buckets.fold(0, (s, b) => s + b.$1);
    final expense = buckets.fold(0, (s, b) => s + b.$2);

    return Scaffold(
      appBar: AppBar(
        // The page's own scaffold sits below the app's, which has the menu.
        leading: const MenuButton(),
        title: _title(range),
        centerTitle: true,
        bottom: SelectedWalletChip.bottomFor(state),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<_Period>(
                  initialValue: _period,
                  onSelected: _choosePeriod,
                  itemBuilder: (_) => [
                    for (final p in _Period.values)
                      PopupMenuItem(value: p, child: Text(_periodName(l, p))),
                  ],
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _periodName(l, _period),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<CategoryType>(
                  // The check mark makes the labels wrap on phones.
                  showSelectedIcon: false,
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
          const SizedBox(height: 12),
          _Summary(
            income: income,
            expense: expense,
            oneWallet: wallet != null,
            currency: state.currency,
          ),
          const SizedBox(height: 16),
          if (totals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
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
                            from: range.from,
                            to: range.to,
                          ),
                        ),
                      ),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            '${l.incomeAndExpense} · ${switch (range.unit) {
              BucketUnit.day => l.daily,
              BucketUnit.week => l.weekly,
              BucketUnit.month => l.monthly,
            }}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: TrendChart(
              buckets: buckets,
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
          if (state.debts.isNotEmpty &&
              (wallet == null || debtEvents.isNotEmpty)) ...[
            const SizedBox(height: 24),
            _DebtSummary(events: debtEvents, showOpen: wallet == null),
          ],
        ],
      ),
    );
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
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
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
              formatMoney(income, currency),
              Colors.green.shade600,
            ),
            cell(
              oneWallet ? l.moneyOut : l.expense,
              formatMoney(expense, currency),
              scheme.error,
            ),
            cell(
              l.net,
              formatMoney(net, currency),
              net >= 0 ? scheme.primary : scheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

/// The period's debt movements, each kind next to its repayments, and
/// what was written off when debts were closed with money still owed.
/// Only the latter counts as income or expense elsewhere.
class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.events, required this.showOpen});

  final List<DebtEvent> events;
  final bool showOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    int sum(bool Function(DebtEvent) test) =>
        events.where(test).fold(0, (s, e) => s + e.effect.abs());
    bool opened(DebtEvent e) => e.payment == null && !e.isClosing;
    final lost = sum((e) => e.isClosing && e.debt.lent);
    final gained = sum((e) => e.isClosing && !e.debt.lent);

    Widget cell(String label, int amount, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            formatMoney(amount, state.currency),
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
    Widget pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [a, const SizedBox(width: 12), b]),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DebtsPage())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l.debts, style: theme.textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              pair(
                cell(l.debtLentEvent, sum((e) => opened(e) && e.debt.lent)),
                cell(
                  l.repaymentReceived,
                  sum((e) => e.payment != null && e.debt.lent),
                ),
              ),
              pair(
                cell(
                  l.debtBorrowedEvent,
                  sum((e) => opened(e) && !e.debt.lent),
                ),
                cell(
                  l.repaymentMade,
                  sum((e) => e.payment != null && !e.debt.lent),
                ),
              ),
              if (lost > 0 || gained > 0)
                pair(
                  cell(
                    l.closedUncollected,
                    lost,
                    color: lost > 0 ? theme.colorScheme.error : null,
                  ),
                  cell(
                    l.closedUnpaid,
                    gained,
                    color: gained > 0 ? Colors.green.shade600 : null,
                  ),
                ),
              if (showOpen) ...[
                const Divider(height: 16),
                pair(
                  cell(l.owedToMe, state.totalOwedToMe),
                  cell(l.iOwe, state.totalIOwe),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
            if (onTap != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Income (green) and expenses (red) side by side per bucket, or only the
/// expense side in the [single] colour.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.buckets,
    required this.labelOf,
    required this.shortLabelOf,
    required this.labelEvery,
    required this.currency,
    this.single,
    this.labelFromEnd = false,
  });

  final List<(int income, int expense)> buckets;
  final String Function(int) labelOf;
  final String Function(int) shortLabelOf;
  final int labelEvery;
  final String currency;

  /// Set to show one series only: the expense or income side.
  final Color? single;

  /// Count [labelEvery] back from the last bar, so the latest is labelled.
  final bool labelFromEnd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final incomeColor = Colors.green.shade600;
    final expenseColor = Theme.of(context).colorScheme.error;
    final maxY = buckets.fold<double>(
      0,
      (m, b) => math.max(m, math.max(b.$1, b.$2) / 100),
    );
    final many = buckets.length > 16;
    final width = single != null
        ? (many ? 6.0 : 14.0)
        : (many ? 3.0 : (buckets.length > 8 ? 6.0 : 10.0));
    BarChartRodData rod(int cents, Color color) => BarChartRodData(
      toY: cents / 100,
      color: color,
      width: width,
      borderRadius: BorderRadius.circular(2),
    );
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
                final n = labelFromEnd ? buckets.length - 1 - i : i;
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
            // Plain light text on a dark bubble; colours are hard to read
            // there, so the series is named instead.
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              [
                labelOf(group.x),
                [
                  if (single == null)
                    rodIndex == 0 ? '${l.income}: ' : '${l.expense}: ',
                  formatMoney((rod.toY * 100).round(), currency),
                ].join(),
              ].join('\n'),
              TextStyle(color: scheme.onInverseSurface, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 1,
              barRods: single != null
                  ? [rod(buckets[i].$2, single!)]
                  : [
                      rod(buckets[i].$1, incomeColor),
                      rod(buckets[i].$2, expenseColor),
                    ],
            ),
        ],
      ),
    );
  }
}
