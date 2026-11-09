import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/state/app_state.dart';

/// Opens an in-memory app, adds an expense through the UI and checks it is
/// listed. [strings] holds the UI texts for the language under test.
Future<void> addRecordFlow(
  WidgetTester tester, {
  required String language,
  required Map<String, String> strings,
  required String category,
  required String formattedAmount,
}) async {
  late AppState state;
  await tester.runAsync(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
      language: language,
    );
    // Skip the welcome screen of a fresh install.
    await db.setSetting('onboarded', '1');
    state = AppState(db);
    await state.load();
    await state.setLanguage(language);
  });

  await tester.pumpWidget(YasbaApp(state: state));
  await tester.pumpAndSettle();
  expect(find.text(strings['empty']!), findsOneWidget);

  await tester.tap(find.text(strings['add']!));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).first, '250.75');
  await tester.tap(find.text(category));
  await tester.pump();
  await tester.enterText(
    find.widgetWithText(TextFormField, strings['title']!),
    'Migros',
  );

  final save = find.text(strings['save']!);
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  // Database calls are real I/O; wait for them to finish.
  for (var i = 0; i < 20 && state.periodRecords.isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.text(strings['newRecord']!), findsNothing);

  expect(find.text('Migros'), findsOneWidget);
  expect(state.periodExpense, 25075);
  expect(find.textContaining(formattedAmount), findsWidgets);

  // Swiping a record does not delete it (too easy to do by accident).
  await tester.timedDrag(
    find.text('Migros'),
    const Offset(-300, 0),
    const Duration(seconds: 1),
  );
  await tester.pumpAndSettle();
  expect(find.text('Migros'), findsOneWidget);
  expect(state.periodRecords, hasLength(1));

  // Close so the next test gets a fresh in-memory database.
  await tester.runAsync(() => state.db.close());
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });

  testWidgets('add record flow in English', (tester) async {
    await addRecordFlow(
      tester,
      language: 'en',
      strings: const {
        'empty': 'No records in this period.',
        'add': 'Add record',
        'title': 'Title (optional)',
        'save': 'Save',
        'newRecord': 'New record',
      },
      category: 'Groceries',
      formattedAmount: '250.75',
    );
  });

  testWidgets('add record flow in Turkish', (tester) async {
    await addRecordFlow(
      tester,
      language: 'tr',
      strings: const {
        'empty': 'Bu dönemde kayıt yok.',
        'add': 'Kayıt ekle',
        'title': 'Başlık (isteğe bağlı)',
        'save': 'Kaydet',
        'newRecord': 'Yeni kayıt',
      },
      category: 'Market',
      formattedAmount: '250,75',
    );
  });

  testWidgets('transfer between wallets', (tester) async {
    late AppState state;
    late int cash, bank;
    await tester.runAsync(() async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      cash = (await db.wallets()).single.id!;
      bank = await db.insertWallet(
        const Wallet(name: 'Bank', color: 0xFF42A5F5),
      );
      // Skip the welcome screen of a fresh install.
      await db.setSetting('onboarded', '1');
      state = AppState(db);
      await state.load();
      await state.setLanguage('en');
    });

    await tester.pumpWidget(YasbaApp(state: state));
    await tester.pumpAndSettle();
    // No wallet selected: no wallet label on the records page.
    expect(find.byType(InputChip), findsNothing);

    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('New transfer'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '120');

    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    for (var i = 0; i < 20 && state.periodTransfers.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    // Without a filter the row says what happens to each wallet.
    expect(find.text(r'Cash -$120.00'), findsOneWidget);
    expect(find.text(r'Bank +$120.00'), findsOneWidget);
    expect(state.balances[cash], -12000);
    expect(state.balances[bank], 12000);
    // Across all wallets, transfers are neither income nor expense.
    expect(state.periodIncome + state.periodExpense, 0);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Net'), findsOneWidget);

    /// Chooses a wallet on the Wallets page, which goes back to Records.
    Future<void> chooseWallet(String name) async {
      await tester.tap(find.text('Wallets'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(ListTile), matching: find.text(name)),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    // Choosing the bank shows the transfer as money coming in.
    await chooseWallet('Bank');
    expect(state.walletFilter, bank);
    expect(find.widgetWithText(InputChip, 'Bank'), findsOneWidget);
    expect(find.text(r'+$120.00'), findsWidgets);
    // One wallet: the summary works like a bank statement.
    expect(find.text('Money in'), findsOneWidget);
    expect(state.periodTransfersIn, 12000);
    expect(state.periodTransfersOut, 0);

    // ...and for the cash wallet as money going out.
    await chooseWallet('Cash');
    expect(state.walletFilter, cash);
    expect(find.text(r'-$120.00'), findsWidgets);
    expect(find.text('Money out'), findsOneWidget);
    expect((state.periodTransfersIn, state.periodTransfersOut), (0, 12000));

    // The label's ✕ shows all wallets again.
    await tester.tap(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.byTooltip('All wallets'),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(state.walletFilter, isNull);
    expect(find.byType(InputChip), findsNothing);

    await tester.runAsync(() => state.db.close());
  });
}
