import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yafa/data/app_database.dart';
import 'package:yafa/main.dart';
import 'package:yafa/models/record.dart';
import 'package:yafa/models/recurring_rule.dart';
import 'package:yafa/state/app_state.dart';

/// Renders the main screens in English and Turkish with sample data and
/// saves them as phone-sized PNGs (1080x2340). Not part of `flutter test`:
///
///   SHOT_DIR=/some/dir flutter test test_screens/screens_test.dart
final fonts =
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
    '/bin/cache/artifacts/material_fonts';
final out = Platform.environment['SHOT_DIR'] ?? 'build/screenshots';

Future<void> loadFonts() async {
  Future<ByteData> f(String n) async =>
      ByteData.sublistView(File('$fonts/$n').readAsBytesSync());
  await (FontLoader('Roboto')
        ..addFont(f('Roboto-Regular.ttf'))
        ..addFont(f('Roboto-Medium.ttf'))
        ..addFont(f('Roboto-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(f('MaterialIcons-Regular.otf'))).load();
}

Future<void> seed(AppDatabase db, String lang) async {
  final cats = await db.categories();
  int id(String en, String tr) =>
      cats.firstWhere((c) => c.name == (lang == 'tr' ? tr : en)).id!;
  final now = DateTime.now();
  DateTime d(int day, [int h = 12]) => DateTime(now.year, now.month, day, h);
  final today = now.day;
  final rows = <(String, int, int, int)>[
    // title, cents, day offset (days before today), category id
    (
      lang == 'tr' ? 'Migros' : 'Supermarket',
      84250,
      0,
      id('Groceries', 'Market'),
    ),
    (lang == 'tr' ? 'Kahve' : 'Coffee', 9500, 0, id('Eating out', 'Yeme-İçme')),
    (
      lang == 'tr' ? 'Metro kart' : 'Metro card',
      25000,
      1,
      id('Transport', 'Ulaşım'),
    ),
    (
      lang == 'tr' ? 'Elektrik' : 'Electricity',
      61240,
      1,
      id('Bills', 'Faturalar'),
    ),
    (
      lang == 'tr' ? 'Sinema' : 'Cinema',
      32000,
      2,
      id('Entertainment', 'Eğlence'),
    ),
    (
      lang == 'tr' ? 'Akşam yemeği' : 'Dinner',
      145000,
      3,
      id('Eating out', 'Yeme-İçme'),
    ),
    (
      lang == 'tr' ? 'Ayakkabı' : 'Shoes',
      229900,
      4,
      id('Shopping', 'Alışveriş'),
    ),
    (lang == 'tr' ? 'Eczane' : 'Pharmacy', 18750, 5, id('Health', 'Sağlık')),
  ];
  for (final (t, c, off, cat) in rows) {
    final day = (today - off).clamp(1, 28);
    await db.insertRecord(
      Record(title: t, amount: c, date: d(day, 18 - off), categoryId: cat),
    );
  }
  await db.insertRecurringRule(
    RecurringRule(
      title: lang == 'tr' ? 'Maaş' : 'Salary',
      amount: 4500000,
      categoryId: id('Salary', 'Maaş'),
      startDate: DateTime(now.year, now.month, 1, 9),
    ),
  );
  await db.insertRecurringRule(
    RecurringRule(
      title: lang == 'tr' ? 'Kira' : 'Rent',
      amount: 1800000,
      categoryId: id('Rent', 'Kira'),
      startDate: DateTime(now.year, now.month, 1, 10),
    ),
  );
  await db.insertRecurringRule(
    RecurringRule(
      title: 'Netflix',
      amount: 22999,
      categoryId: id('Entertainment', 'Eğlence'),
      startDate: DateTime(now.year, now.month - 2, 15),
    ),
  );
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('root')),
  );
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 3);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<AppState> start(WidgetTester tester, String lang) async {
  late AppState state;
  await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('shots');
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${dir.path}/$lang.db',
      language: lang,
    );
    await seed(db, lang);
    if (lang == 'en') await db.setSetting('currency', '₺');
    state = AppState(db);
    await state.load();
    await state.setLanguage(lang);
  });
  // flutter_test draws shadows as black outlines unless enabled.
  debugDisableShadows = false;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('root'),
      child: YafaApp(state: state),
    ),
  );
  return state;
}

Future<void> tapNav(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // flutter_test draws shadows as thick black outlines unless disabled.
    debugDisableShadows = false;
    sqfliteFfiInit();
    await initializeDateFormatting();
    await loadFonts();
  });

  for (final lang in ['en', 'tr']) {
    testWidgets('screens $lang', (tester) async {
      final state = await start(tester, lang);
      await shot(tester, '${lang}_1_records');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_2_add_record');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tapNav(tester, Icons.pie_chart_outline);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await shot(tester, '${lang}_3_stats');

      await tapNav(tester, Icons.settings_outlined);
      await shot(tester, '${lang}_4_settings');

      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_5_recurring');

      await tester.runAsync(() => state.db.close());
      tester.view.reset();
      debugDisableShadows = true;
    });
  }
}
