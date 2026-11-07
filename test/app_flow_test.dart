import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yafa/data/app_database.dart';
import 'package:yafa/main.dart';
import 'package:yafa/state/app_state.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('kayıt ekleme akışı', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      state = AppState(db);
      await state.load();
    });

    await tester.pumpWidget(YafaApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Bu ay için kayıt yok.'), findsOneWidget);

    await tester.tap(find.text('Kayıt ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '250,75');
    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Başlık (isteğe bağlı)'),
      'Migros',
    );

    final save = find.text('Kaydet');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    // Veritabanı işlemleri gerçek I/O; bitmelerini bekle.
    for (var i = 0; i < 20 && state.monthRecords.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Yeni kayıt'), findsNothing);

    expect(find.text('Migros'), findsOneWidget);
    expect(state.monthExpense, 25075);
    expect(find.textContaining('250,75'), findsWidgets);

    await tester.runAsync(() => state.db.close());
  });
}
