import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/period.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/state/app_state.dart';

Future<AppState> openApp(WidgetTester tester) async {
  late AppState state;
  await tester.runAsync(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    // Skip the welcome screen of a fresh install.
    await db.setSetting('onboarded', '1');
    state = AppState(db);
    await state.load();
    await state.setLanguage('en');
  });
  await tester.pumpWidget(YasbaApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Lets real database I/O finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });

  testWidgets('tapping the month opens a picker to jump to any month', (
    tester,
  ) async {
    final state = await openApp(tester);
    final now = DateTime.now();

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expect(find.text('Choose a period'), findsOneWidget);

    // Go back a year and pick March.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.chevron_left),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('${now.year - 1}'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await settle(tester);

    expect(state.period.from, DateTime(now.year - 1, 3));
    expect(find.text('March ${now.year - 1}'), findsOneWidget);

    // The whole year, then the last 3 months.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All of ${now.year - 1}'));
    await settle(tester);
    expect(state.period.kind, PeriodKind.year);
    expect(find.text('${now.year - 1}'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 3 months'));
    await settle(tester);
    expect(state.period.kind, PeriodKind.last3Months);
    expect(state.period.to, DateTime(now.year, now.month + 1));
    // Back by its own length: the three months before.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await settle(tester);
    expect(state.period.from, DateTime(now.year, now.month - 5));
    expect(state.period.to, DateTime(now.year, now.month - 2));
    await tester.runAsync(() => state.db.close());
  });

  testWidgets('bottom navigation and side menu', (tester) async {
    final state = await openApp(tester);

    // Three tabs; the app opens on Records, in the middle.
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Add record'), findsOneWidget);
    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();
    expect(find.text('All wallets'), findsOneWidget);

    /// Opens the side menu from the current page and picks [item].
    Future<void> openFromMenu(String item) async {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('YASBA'), findsOneWidget);
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    // Categories: expense/income buttons, add button follows the type.
    await openFromMenu('Categories');
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Recurring transactions.
    await openFromMenu('Recurring transactions');
    expect(find.textContaining('rent, salary'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New recurring transaction'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Settings.
    await openFromMenu('Settings');
    expect(find.text('Automatic backup'), findsOneWidget);
    await tester.runAsync(() => state.db.close());
  });

  testWidgets('tapping a wallet filters records and statistics', (
    tester,
  ) async {
    late AppState state;
    late int bank;
    await tester.runAsync(() async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
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

    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await settle(tester);

    // Back on Records, filtered to the bank.
    expect(state.walletFilter, bank);
    expect(find.text('Add record'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Bank'), findsOneWidget);

    // "All wallets" on the Wallets page clears the filter.
    await tester.tap(find.text('Wallets').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('All wallets'),
      ),
    );
    await settle(tester);
    expect(state.walletFilter, isNull);

    // The edit button still opens the wallet.
    await tester.tap(find.text('Wallets').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit wallet').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit wallet'), findsOneWidget);
    await tester.runAsync(() => state.db.close());
  });
}
