import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/period.dart';
import 'period_picker.dart';

/// The shown period, with arrows to the previous and next one; tap it to
/// pick another. Used in the records and statistics app bars.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final Period period;
  final ValueChanged<Period> onChanged;

  /// "November 2026", "2026", "Sep 2026 – Nov 2026" or "Sep 1 – Nov 15, 2026".
  static String label(Period p) {
    switch (p.kind) {
      case PeriodKind.month:
        return toBeginningOfSentenceCase(DateFormat.yMMMM().format(p.from));
      case PeriodKind.year:
        return '${p.from.year}';
      case PeriodKind.last3Months:
      case PeriodKind.last12Months:
        return '${DateFormat.yMMM().format(p.from)} – '
            '${DateFormat.yMMM().format(p.last)}';
      case PeriodKind.custom:
        // Whole months read better as months.
        if (p.from.day == 1 && p.to.day == 1) {
          return '${DateFormat.yMMM().format(p.from)} – '
              '${DateFormat.yMMM().format(p.last)}';
        }
        return '${DateFormat.yMMMd().format(p.from)} – '
            '${DateFormat.yMMMd().format(p.last)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: l.previous,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(period.shift(-1)),
        ),
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showPeriodPicker(context, initial: period);
              if (picked != null) onChanged(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label(period),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style:
                            period.kind == PeriodKind.month ||
                                period.kind == PeriodKind.year
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l.next,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(period.shift(1)),
        ),
      ],
    );
  }
}
