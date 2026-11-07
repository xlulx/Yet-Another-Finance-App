import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yafa/data/app_database.dart';
import 'package:yafa/main.dart';
import 'package:yafa/state/app_state.dart';

Future<AppState> openApp(WidgetTester tester) async {
  late AppState state;
  await tester.runAsync(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    state = AppState(db);
    await state.load();
    await state.setLanguage('en');
  });
  await tester.pumpWidget(YafaApp(state: state));
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
    expect(find.text('Choose month'), findsOneWidget);

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

    expect(state.month, DateTime(now.year - 1, 3));
    expect(find.text('March ${now.year - 1}'), findsOneWidget);
    await tester.runAsync(() => state.db.close());
  });

  testWidgets('wallets, categories and recurring are swipeable tabs', (
    tester,
  ) async {
    final state = await openApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();

    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);

    // Swipe to categories; the type is picked with buttons, not tabs.
    await tester.fling(find.text('Total balance'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);

    // The add button follows the tab: a new income category here.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Swipe on to recurring transactions.
    await tester.fling(find.text('Salary'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.textContaining('rent, salary'), findsOneWidget);
    await tester.runAsync(() => state.db.close());
  });
}
