import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/debt.dart';
import 'package:yasba/models/record.dart';
import 'package:yasba/models/recurring_rule.dart';
import 'package:yasba/models/transfer.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/state/app_state.dart';

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
  final cash = (await db.wallets()).first.id!;
  final bank = await db.insertWallet(
    Wallet(
      name: lang == 'tr' ? 'Banka' : 'Bank',
      color: 0xFF1E88E5,
      icon: 'bank',
      initialBalance: 1250000,
      sortOrder: 1,
    ),
  );
  await db.insertWallet(
    Wallet(
      name: lang == 'tr' ? 'Kredi kartı' : 'Credit card',
      color: 0xFF5C6BC0,
      icon: 'card',
      initialBalance: -340000,
      sortOrder: 2,
    ),
  );
  var i = 0;
  for (final (t, c, off, cat) in rows) {
    final day = (today - off).clamp(1, 28);
    await db.insertRecord(
      Record(
        title: t,
        amount: c,
        date: d(day, 18 - off),
        categoryId: cat,
        walletId: (i++).isEven ? bank : cash,
      ),
    );
  }
  await db.insertTransfer(
    Transfer(
      fromWalletId: bank,
      toWalletId: cash,
      amount: 200000,
      date: d(today.clamp(1, 28), 10),
      note: lang == 'tr' ? 'ATM' : 'ATM',
    ),
  );
  final lent = await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Ali' : 'Alex',
      direction: DebtDirection.lent,
      amount: 150000,
      date: d((today - 6).clamp(1, 28)),
      dueDate: DateTime(now.year, now.month + 1, 1),
      walletId: bank,
    ),
  );
  await db.insertDebtPayment(
    DebtPayment(
      debtId: lent,
      amount: 50000,
      date: d((today - 1).clamp(1, 28), 20),
      walletId: cash,
    ),
  );
  await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Ayşe' : 'Emma',
      direction: DebtDirection.borrowed,
      amount: 300000,
      date: DateTime(now.year, now.month - 1, 12),
      dueDate: DateTime(now.year, now.month, 1),
      note: lang == 'tr' ? 'Tatil' : 'Holiday',
      walletId: cash,
    ),
  );
  await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Mert' : 'Sam',
      direction: DebtDirection.lent,
      amount: 20000,
      date: DateTime(now.year, now.month - 1, 3),
      closed: true,
      closedAt: d((today - 2).clamp(1, 28), 11),
    ),
  );
  final kept = await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Zeynep' : 'Mia',
      direction: DebtDirection.borrowed,
      amount: 40000,
      date: DateTime(now.year, now.month - 1, 20),
      walletId: cash,
      closed: true,
      closedAt: d((today - 3).clamp(1, 28), 12),
    ),
  );
  await db.insertDebtPayment(
    DebtPayment(
      debtId: kept,
      amount: 25000,
      date: DateTime(now.year, now.month - 1, 28),
      walletId: cash,
    ),
  );
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
      child: YasbaApp(state: state),
    ),
  );
  return state;
}

Future<void> tapNav(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

/// Selects the wallet called [name] (null for all wallets) and lets the
/// database work finish.
Future<void> pickWallet(
  WidgetTester tester,
  AppState state,
  String? name,
) async {
  await tester.runAsync(
    () => state.setWalletFilter(
      name == null ? null : state.wallets.firstWhere((w) => w.name == name).id,
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
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

      // The same month filtered to the cash wallet.
      await pickWallet(tester, state, lang == 'tr' ? 'Nakit' : 'Cash');
      await shot(tester, '${lang}_1b_records_one_wallet');
      await pickWallet(tester, state, null);

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
      await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3c_stats_debts');
      await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await pickWallet(tester, state, lang == 'tr' ? 'Banka' : 'Bank');
      await shot(tester, '${lang}_3b_stats_one_wallet');
      await pickWallet(tester, state, null);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_4_menu');
      for (final (icon, name) in [
        (Icons.settings_outlined, '4b_settings'),
        (Icons.category_outlined, '5_categories'),
        (Icons.repeat, '5b_recurring'),
      ]) {
        if (find.byType(Drawer).evaluate().isEmpty) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(of: find.byType(Drawer), matching: find.byIcon(icon)),
        );
        await tester.pumpAndSettle();
        await shot(tester, '${lang}_$name');
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.handshake_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_8_debts');
      await tester.tap(find.textContaining(lang == 'tr' ? 'Ali' : 'Alex'));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_8b_debt_detail');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_8c_payment');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_8d_add_debt');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tapNav(tester, Icons.account_balance_wallet_outlined);
      await shot(tester, '${lang}_6_wallets');

      await tapNav(tester, Icons.receipt_long_outlined);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.swap_horiz).first);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_7_transfer');

      await tester.runAsync(() => state.db.close());
      tester.view.reset();
      debugDisableShadows = true;
    });
  }
}
