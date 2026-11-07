import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Lets the user pick a month (a year with arrows, then one of 12 months),
/// or only a year when [yearOnly]. Returns null when cancelled.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initial,
  bool yearOnly = false,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial, yearOnly: yearOnly),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial, required this.yearOnly});

  final DateTime initial;
  final bool yearOnly;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  /// Shown year (months) or first year of the shown page of 12 (years).
  late int _year = widget.yearOnly
      ? widget.initial.year - 7
      : widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final step = widget.yearOnly ? 12 : 1;
    final header = widget.yearOnly ? '$_year – ${_year + 11}' : '$_year';

    Widget cell(String label, DateTime value, bool selected, bool current) {
      // Small padding and a FittedBox so labels like "May" never get cut.
      const padding = EdgeInsets.symmetric(horizontal: 4);
      final text = FittedBox(child: Text(label, maxLines: 1));
      return Padding(
        padding: const EdgeInsets.all(4),
        child: selected
            ? FilledButton(
                style: FilledButton.styleFrom(padding: padding),
                onPressed: () => Navigator.pop(context, value),
                child: text,
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: padding,
                  side: BorderSide(
                    color: current ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                onPressed: () => Navigator.pop(context, value),
                child: text,
              ),
      );
    }

    final cells = <Widget>[
      for (var i = 0; i < 12; i++)
        if (widget.yearOnly)
          cell(
            '${_year + i}',
            DateTime(_year + i, widget.initial.month),
            _year + i == widget.initial.year,
            _year + i == now.year,
          )
        else
          cell(
            toBeginningOfSentenceCase(
              DateFormat.MMM().format(DateTime(_year, i + 1)),
            ),
            DateTime(_year, i + 1),
            _year == widget.initial.year && i + 1 == widget.initial.month,
            _year == now.year && i + 1 == now.month,
          ),
    ];

    return AlertDialog(
      title: Text(widget.yearOnly ? l.pickYear : l.pickMonth),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l.previous,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _year -= step),
                ),
                Expanded(
                  child: Text(
                    header,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l.next,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _year += step),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
          ],
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
