import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'month_picker.dart';

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
        // Tap the label to jump to any month (or year).
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showMonthPicker(
              context,
              initial: month,
              yearOnly: yearOnly,
            );
            if (picked != null) onChanged(picked);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
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
