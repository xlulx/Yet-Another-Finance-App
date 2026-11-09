import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/period.dart';

/// Lets the user pick a month (a year with arrows, then one of 12 months),
/// a whole year, the last 3 or 12 months, or any range of days. Returns
/// null when cancelled.
Future<Period?> showPeriodPicker(
  BuildContext context, {
  required Period initial,
}) async {
  final picked = await showDialog<Object>(
    context: context,
    builder: (_) => _PeriodPickerDialog(initial: initial),
  );
  if (picked is Period || picked == null || !context.mounted) {
    return picked as Period?;
  }
  // "Custom range" chosen: the date range picker takes over.
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(1990),
    lastDate: DateTime(2100),
    initialDateRange: DateTimeRange(start: initial.from, end: initial.last),
  );
  return range == null ? null : Period.custom(range.start, range.end);
}

/// Returned by the dialog when "Custom range" is chosen.
const _custom = 'custom';

class _PeriodPickerDialog extends StatefulWidget {
  const _PeriodPickerDialog({required this.initial});

  final Period initial;

  @override
  State<_PeriodPickerDialog> createState() => _PeriodPickerDialogState();
}

class _PeriodPickerDialogState extends State<_PeriodPickerDialog> {
  /// The year whose months are shown.
  late int _year = widget.initial.last.year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final initial = widget.initial;

    Widget choice(String label, Object value, bool selected, {bool? current}) {
      // Small padding and a FittedBox so labels like "May" never get cut.
      const padding = EdgeInsets.symmetric(horizontal: 4);
      final text = FittedBox(child: Text(label, maxLines: 1));
      void pick() => Navigator.pop(context, value);
      return Padding(
        padding: const EdgeInsets.all(4),
        child: selected
            ? FilledButton(
                style: FilledButton.styleFrom(padding: padding),
                onPressed: pick,
                child: text,
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: padding,
                  side: BorderSide(
                    color: current == true
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
                onPressed: pick,
                child: text,
              ),
      );
    }

    final months = <Widget>[
      for (var i = 0; i < 12; i++)
        choice(
          toBeginningOfSentenceCase(
            DateFormat.MMM().format(DateTime(_year, i + 1)),
          ),
          Period.month(DateTime(_year, i + 1)),
          initial == Period.month(DateTime(_year, i + 1)),
          current: _year == now.year && i + 1 == now.month,
        ),
    ];

    return AlertDialog(
      title: Text(l.pickPeriod),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l.previous,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _year--),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.next,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _year++),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: months,
              ),
              const Divider(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                childAspectRatio: 3.4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  choice(
                    l.wholeYear('$_year'),
                    Period.year(_year),
                    initial == Period.year(_year),
                  ),
                  choice(
                    l.periodLast3Months,
                    Period.lastMonths(3, now),
                    initial.kind == PeriodKind.last3Months,
                  ),
                  choice(
                    l.periodLast12Months,
                    Period.lastMonths(12, now),
                    initial.kind == PeriodKind.last12Months,
                  ),
                  choice(
                    l.periodCustom,
                    _custom,
                    initial.kind == PeriodKind.custom,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
