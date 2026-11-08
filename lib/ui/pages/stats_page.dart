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
import '../widgets/menu_button.dart';
import '../widgets/category_avatar.dart';
import '../widgets/month_selector.dart';
import '../widgets/selected_wallet_chip.dart';
import 'debts_page.dart';

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
  List<Transfer> _transfers = [];
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
    final wallet = _state!.walletFilter;
    final records = await _state!.db.records(
      from: _from,
      to: _to,
      walletId: wallet,
    );
    // Like a bank statement, one wallet's statistics include its transfers.
    // Across all wallets they cancel out and are left out.
    final transfers = wallet == null
        ? <Transfer>[]
        : await _state!.db.transfers(from: _from, to: _to, walletId: wallet);
    if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final byId = {for (final c in state.categories) c.id!: c};
    final wallet = state.walletFilter;
    // Debt movements in the period that touched a wallet (the filtered one,
    // if any).
    final debtEvents = [
      for (final e in state.allDebtEvents())
        if (!e.date.isBefore(_from) &&
            e.date.isBefore(_to) &&
            e.walletId != null &&
            // Counted as the expense or income record instead.
            !e.forgiven &&
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
      // Like transfers, one wallet's debt money in and out; one slice per
      // person.
      for (final (person, total, count) in debtTotals(debtEvents, _type)) {
        totals.add(
          CategoryTotal(
            Category(
              name: l.debtSlice(person),
              type: _type,
              color:
                  categoryColors[person.toLowerCase().hashCode.abs() %
                      categoryColors.length],
              icon: debtIconKey,
            ),
            total,
            count,
          ),
        );
      }
      totals.sort((a, b) => b.total.compareTo(a.total));
    }
    final sum = totals.fold(0, (s, t) => s + t.total);

    final bucketCount = _period == _Period.month
        ? DateTime(_anchor.year, _anchor.month + 1, 0).day
        : 12;
    final buckets = bucketTotals(
      _records,
      byId,
      bucketCount,
      _period == _Period.month ? (d) => d.day - 1 : (d) => d.month - 1,
      transfers: _transfers,
      walletId: wallet,
      debtEvents: debtEvents,
    );

    return Scaffold(
      appBar: AppBar(
        // The page's own scaffold sits below the app's, which has the menu.
        leading: const MenuButton(),
        title: MonthSelector(
          month: _anchor,
          yearOnly: _period == _Period.year,
          onChanged: (m) => _update(() => _anchor = m),
        ),
        centerTitle: true,
        bottom: SelectedWalletChip.bottomFor(state),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_Period>(
                  // The check mark makes the labels wrap on phones.
                  showSelectedIcon: false,
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

/// The period's debt movements by kind and, across all wallets, what is
/// still open. Debts are not income or expense, so they get their own card.
class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.events, required this.showOpen});

  final List<DebtEvent> events;
  final bool showOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    int sum(bool payment, bool lent) => events
        .where((e) => (e.payment != null) == payment && e.debt.lent == lent)
        .fold(0, (s, e) => s + e.effect.abs());
    final rows = [
      (l.debtLentEvent, -sum(false, true)),
      (l.debtBorrowedEvent, sum(false, false)),
      (l.repaymentReceived, sum(true, true)),
      (l.repaymentMade, -sum(true, false)),
    ];
    final theme = Theme.of(context);
    Widget line(String label, int amount, {bool signed = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatMoney(amount, state.currency, signed: signed && amount != 0),
            style: TextStyle(
              color: signed && amount > 0 ? Colors.green.shade600 : null,
            ),
          ),
        ],
      ),
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
              const SizedBox(height: 4),
              for (final (label, amount) in rows)
                if (amount != 0) line(label, amount),
              if (showOpen) ...[
                const Divider(height: 16),
                line(l.owedToMe, state.totalOwedToMe, signed: false),
                line(l.iOwe, state.totalIOwe, signed: false),
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
