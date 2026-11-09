import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/record.dart';
import 'package:yasba/state/app_state.dart';
import 'package:yasba/ui/home_shell.dart';
import 'package:yasba/ui/pages/welcome_page.dart';

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

  Future<AppDatabase> open() => AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
    language: 'en',
  );

  test('only a fresh install gets the welcome screen', () async {
    final fresh = await open();
    final a = AppState(fresh);
    await a.load();
    expect(a.needsOnboarding, isTrue);
    await fresh.close();

    // Someone updating the app already has data: never shown, and remembered.
    final used = await open();
    await used.insertRecord(
      Record(
        title: 'Coffee',
        amount: 300,
        date: DateTime(2025, 3, 1),
        categoryId: (await used.categories()).first.id!,
      ),
    );
    final b = AppState(used);
    await b.load();
    expect(b.needsOnboarding, isFalse);
    expect(await used.getSetting('onboarded'), '1');
    await used.close();
  });

  testWidgets('choose Turkish and a starting balance, then start', (
    tester,
  ) async {
    late AppDatabase db;
    late AppState state;
    await tester.runAsync(() async {
      db = await open();
      state = AppState(db);
      await state.load();
      await state.setLanguage('en');
    });
    await tester.pumpWidget(YasbaApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Welcome to YASBA'), findsOneWidget);

    // Turkish: the screen and the defaults made in English switch over.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Türkçe').last);
    await settle(tester);
    expect(find.text("YASBA'ya hoş geldin"), findsOneWidget);
    expect(state.wallets.single.name, 'Nakit');
    expect(state.categories.map((c) => c.name), contains('Market'));

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '250,50');
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başla'));
    await settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(state.balances[state.wallets.single.id], 25050);
    expect(await tester.runAsync(() => db.getSetting('onboarded')), '1');
    await tester.runAsync(() => db.close());
  });
}
