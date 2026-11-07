import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
    this.yearOnly = false,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool yearOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = yearOnly
        ? '${month.year}'
        : toBeginningOfSentenceCase(DateFormat.yMMMM().format(month));
    DateTime shift(int d) => yearOnly
        ? DateTime(month.year + d, month.month)
        : DateTime(month.year, month.month + d);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: l.previous,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(shift(-1)),
        ),
        SizedBox(
          width: 160,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: l.next,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(shift(1)),
        ),
      ],
    );
  }
}
