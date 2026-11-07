import '../data/app_database.dart';
import '../models/record.dart';
import 'recurrence.dart';

/// Creates all due recurring records and returns how many were created.
/// Called on app start and whenever a rule changes.
Future<int> generateDueRecurringRecords(AppDatabase db, DateTime now) {
  return db.db.transaction((txn) async {
    var created = 0;
    for (final rule in await db.recurringRules(txn: txn)) {
      final dates = pendingOccurrences(rule, now);
      if (dates.isEmpty) continue;
      for (final date in dates) {
        await db.insertRecord(
          Record(
            title: rule.title,
            amount: rule.amount,
            date: date,
            categoryId: rule.categoryId,
            note: rule.note,
            recurringId: rule.id,
          ),
          txn: txn,
        );
      }
      created += dates.length;
      await db.updateRecurringRule(
        rule.copyWith(lastGenerated: dates.last),
        txn: txn,
      );
    }
    return created;
  });
}
