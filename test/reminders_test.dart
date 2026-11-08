import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/l10n/app_localizations.dart';
import 'package:yasba/models/category.dart';
import 'package:yasba/models/debt.dart';
import 'package:yasba/models/recurring_rule.dart';
import 'package:yasba/services/reminders.dart';
import 'package:yasba/state/app_state.dart';

class _FakeScheduler extends ReminderScheduler {
  bool allow = true;
  int calls = 0;
  List<Reminder> scheduled = [];

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> replaceAll(List<Reminder> reminders, AppLocalizations l) async {
    calls++;
    scheduled = reminders;
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });

  final l = lookupAppLocalizations(const Locale('tr'));
  const rent = Category(
    id: 1,
    name: 'Kira',
    type: CategoryType.expense,
    color: 0,
  );

  test('one notification per day at the chosen time', () {
    final now = DateTime(2025, 3, 10, 12);
    final reminders = upcomingReminders(
      now: now,
      hour: 9,
      minute: 30,
      l: l,
      currency: '₺',
      rules: [
        RecurringRule(
          id: 1,
          title: '',
          amount: 1500000,
          categoryId: 1,
          startDate: DateTime(2025, 1, 15),
        ),
      ],
      categories: {1: rent},
      debts: [
        Debt(
          person: 'Ali',
          direction: DebtDirection.lent,
          amount: 30000,
          date: DateTime(2025, 3, 1),
          dueDate: DateTime(2025, 3, 15),
        ),
        // Due today, but 9:30 has passed: nothing.
        Debt(
          person: 'Can',
          direction: DebtDirection.borrowed,
          amount: 100,
          date: DateTime(2025, 3, 1),
          dueDate: DateTime(2025, 3, 10),
        ),
        // Closed: nothing.
        Debt(
          person: 'Ayşe',
          direction: DebtDirection.borrowed,
          amount: 100,
          date: DateTime(2025, 3, 1),
          dueDate: DateTime(2025, 3, 20),
          closed: true,
        ),
      ],
      remainingOf: (d) => d.amount ~/ 2,
    );
    // March 15 (rent + Ali) and April 15 (rent), within 45 days.
    expect(reminders.map((r) => r.when), [
      DateTime(2025, 3, 15, 9, 30),
      DateTime(2025, 4, 15, 9, 30),
    ]);
    expect(reminders[0].title, 'Bugün için 2 hatırlatma');
    expect(reminders[0].body!.split('\n'), [
      'Kira -₺15.000,00 · tekrarlayan',
      'Ali bugün sana ₺150,00 ödeyecek',
    ]);
    expect(reminders[1].title, 'Kira -₺15.000,00 · tekrarlayan');
    expect(reminders[1].body, isNull);
  });

  test('turning reminders on schedules them; off cancels', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final scheduler = _FakeScheduler();
    final state = AppState(
      db,
      clock: () => DateTime(2025, 3, 10, 12),
      reminderScheduler: scheduler,
    );
    await state.load();
    await state.setLanguage('tr');
    await state.saveDebt(
      Debt(
        person: 'Ali',
        direction: DebtDirection.lent,
        amount: 30000,
        date: DateTime(2025, 3, 1),
        dueDate: DateTime(2025, 3, 15),
      ),
    );
    // Off by default: nothing scheduled, the plugin is never called.
    expect(scheduler.calls, 0);

    scheduler.allow = false;
    expect(await state.setReminders(debts: true), isFalse);
    expect(state.remindDebts, isFalse);

    scheduler.allow = true;
    expect(await state.setReminders(debts: true), isTrue);
    expect(scheduler.scheduled.single.when, DateTime(2025, 3, 15, 9));
    expect(await db.getSetting(remindDebtsKey), '1');

    await state.setReminderTime(20, 5);
    expect(scheduler.scheduled.single.when, DateTime(2025, 3, 15, 20, 5));

    // Repaid: the reminder goes away.
    await state.addDebtPayment(
      DebtPayment(
        debtId: state.debts.single.id!,
        amount: 30000,
        date: DateTime(2025, 3, 10),
      ),
    );
    expect(scheduler.scheduled, isEmpty);

    await state.setReminders(debts: false);
    expect(scheduler.scheduled, isEmpty);
    await db.close();
  });
}
