import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/debt.dart';
import 'package:yasba/models/category.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/services/stats.dart';
import 'package:yasba/state/app_state.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });

  late AppDatabase db;
  late AppState state;
  late int cash, bank;
  final now = DateTime(2025, 3, 20);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    cash = (await db.wallets()).single.id!;
    bank = await db.insertWallet(
      const Wallet(name: 'Bank', color: 0xFF42A5F5, initialBalance: 100000),
    );
    state = AppState(db, clock: () => now);
    await state.load();
  });
  tearDown(() => db.close());

  Debt debtOf(String person) =>
      state.debts.firstWhere((d) => d.person == person);

  test('debts change wallet balances but are not income or expense', () async {
    await state.saveDebt(
      Debt(
        person: 'Ali',
        direction: DebtDirection.lent,
        amount: 30000,
        date: DateTime(2025, 3, 2),
        walletId: bank,
      ),
    );
    await state.saveDebt(
      Debt(
        person: 'Ayşe',
        direction: DebtDirection.borrowed,
        amount: 50000,
        date: DateTime(2025, 3, 3),
        walletId: cash,
      ),
    );
    // Noted only: changes no balance.
    await state.saveDebt(
      Debt(
        person: 'Can',
        direction: DebtDirection.lent,
        amount: 999,
        date: DateTime(2025, 3, 4),
      ),
    );
    expect(state.balances[bank], 100000 - 30000);
    expect(state.balances[cash], 50000);

    // Ali pays back 10000 in cash; I pay Ayşe 20000 from the bank.
    await state.addDebtPayment(
      DebtPayment(
        debtId: debtOf('Ali').id!,
        amount: 10000,
        date: DateTime(2025, 3, 10),
        walletId: cash,
      ),
    );
    await state.addDebtPayment(
      DebtPayment(
        debtId: debtOf('Ayşe').id!,
        amount: 20000,
        date: DateTime(2025, 3, 11),
        walletId: bank,
      ),
    );
    expect(state.balances[bank], 100000 - 30000 - 20000);
    expect(state.balances[cash], 50000 + 10000);
    expect(state.monthIncome + state.monthExpense, 0);

    // Remaining amounts and totals.
    expect(state.remainingOf(debtOf('Ali')), 20000);
    expect(state.remainingOf(debtOf('Ayşe')), 30000);
    expect(state.totalOwedToMe, 20000 + 999);
    expect(state.totalIOwe, 30000);

    // The records page lists the four movements that touched a wallet.
    await state.setMonth(DateTime(2025, 3));
    expect(state.monthDebtEvents, hasLength(4));
    expect(state.monthDebtIn + state.monthDebtOut, 0); // no wallet filter

    // Seen from the bank: 30000 lent and 20000 repaid went out, but
    // neither is income or expense.
    await state.setWalletFilter(bank);
    expect(
      state.monthDebtEvents.map((e) => e.effect),
      unorderedEquals([-30000, -20000]),
    );
    expect((state.monthDebtIn, state.monthDebtOut), (0, 0));
    await state.setWalletFilter(null);

    // Closing with money still owed: what Ali never paid back is an
    // expense, what I never paid Ayşe is income, on the closing day.
    await state.setDebtClosed(debtOf('Ali'), true);
    await state.setDebtClosed(debtOf('Ayşe'), true);
    expect(debtOf('Ali').closedAt, now);
    expect((state.monthDebtIn, state.monthDebtOut), (30000, 20000));
    final closing = state.monthDebtEvents.where((e) => e.isClosing);
    expect(closing.map((e) => e.date).toSet(), {now});
    // Wallet balances do not change.
    expect(state.balances[bank], 100000 - 30000 - 20000);
    expect(state.balances[cash], 50000 + 10000);
    // Seen from the bank, only Ali's loss.
    await state.setWalletFilter(bank);
    expect((state.monthDebtIn, state.monthDebtOut), (0, 20000));
    await state.setWalletFilter(null);
    // Reopening takes it back.
    await state.setDebtClosed(debtOf('Ali'), false);
    expect(debtOf('Ali').closedAt, isNull);
    expect((state.monthDebtIn, state.monthDebtOut), (30000, 0));

    // A wallet used by a debt cannot be deleted.
    expect(await state.deleteWallet(state.walletById(bank)!), isFalse);
  });

  test('a debt settles when repaid or closed by hand', () async {
    await state.saveDebt(
      Debt(
        person: 'Ali',
        direction: DebtDirection.lent,
        amount: 1000,
        date: DateTime(2025, 3, 1),
        walletId: cash,
      ),
    );
    expect(state.isSettled(debtOf('Ali')), isFalse);
    await state.addDebtPayment(
      DebtPayment(debtId: debtOf('Ali').id!, amount: 1000, date: now),
    );
    expect(state.isSettled(debtOf('Ali')), isTrue);
    expect(state.totalOwedToMe, 0);

    await state.saveDebt(
      Debt(
        person: 'Bora',
        direction: DebtDirection.borrowed,
        amount: 5000,
        date: DateTime(2025, 3, 1),
      ),
    );
    await state.setDebtClosed(debtOf('Bora'), true);
    expect(state.isSettled(debtOf('Bora')), isTrue);
    expect(state.totalIOwe, 0);
    await state.setDebtClosed(debtOf('Bora'), false);
    expect(state.totalIOwe, 5000);

    // Deleting a debt deletes its payments too.
    await state.deleteDebt(debtOf('Ali'));
    expect(await db.debtPayments(), isEmpty);
    expect(state.debtPeople, ['Bora']);
  });

  test('statistics count only what was written off', () {
    final ali = Debt(
      person: 'Ali',
      direction: DebtDirection.lent,
      amount: 30000,
      date: DateTime(2025, 3, 2),
      walletId: 1,
      closed: true,
    );
    final ayse = Debt(
      person: 'Ayşe',
      direction: DebtDirection.borrowed,
      amount: 50000,
      date: DateTime(2025, 3, 3),
      closed: true,
    );
    final events = [
      DebtEvent(ali, null),
      DebtEvent(
        ali,
        DebtPayment(debtId: 1, amount: 10000, date: DateTime(2025, 3, 3)),
      ),
      DebtEvent.closed(ali, 20000, DateTime(2025, 3, 4)),
      DebtEvent(ayse, null),
      DebtEvent.closed(ayse, 50000, DateTime(2025, 3, 5)),
    ];
    expect(debtTotals(events, CategoryType.expense), [('Ali', 20000, 1)]);
    expect(debtTotals(events, CategoryType.income), [('Ayşe', 50000, 1)]);
    final buckets = bucketTotals(
      const [],
      const {},
      31,
      (d) => d.day - 1,
      debtEvents: events,
    );
    expect(buckets.sublist(1, 5), [(0, 0), (0, 0), (0, 20000), (50000, 0)]);
  });

  testWidgets('add a debt and a repayment from the side menu', (tester) async {
    await tester.runAsync(() => state.setLanguage('en'));
    await tester.pumpWidget(YasbaApp(state: state));
    await tester.pumpAndSettle();

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add debt'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ali');
    await tester.enterText(find.byType(TextFormField).at(1), '300');
    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await settle();

    expect(find.text('Ali owes you'), findsOneWidget);
    expect(state.totalOwedToMe, 30000);
    // Lent from the default wallet (cash).
    expect(state.balances[cash], -30000);

    await tester.tap(find.text('Ali owes you'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      '100',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await settle();

    expect(state.remainingOf(debtOf('Ali')), 20000);
    expect(state.balances[cash], -20000);
    expect(find.textContaining('100.00'), findsWidgets);
    await tester.runAsync(() => db.close());
  });
}
