import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yasba/data/app_database.dart';
import 'package:yasba/main.dart';
import 'package:yasba/models/debt.dart';
import 'package:yasba/models/period.dart';
import 'package:yasba/models/record.dart';
import 'package:yasba/models/recurring_rule.dart';
import 'package:yasba/models/transfer.dart';
import 'package:yasba/models/wallet.dart';
import 'package:yasba/services/reminders.dart';
import 'package:yasba/state/app_state.dart';

/// Renders the main screens in English and Turkish with sample data and
/// saves them as phone-sized PNGs (1080x2340, or 1080 by SHOT_HEIGHT; 1920
/// for the store images, see store/compose.js). Not part of `flutter test`:
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
  // English shots are in dollars, with amounts to match.
  int m(int cents) => lang == 'tr' ? cents : (cents / 10).round();
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
      initialBalance: m(1250000),
      sortOrder: 1,
    ),
  );
  await db.insertWallet(
    Wallet(
      name: lang == 'tr' ? 'Kredi kartı' : 'Credit card',
      color: 0xFF5C6BC0,
      icon: 'card',
      initialBalance: m(-340000),
      sortOrder: 2,
    ),
  );
  var i = 0;
  for (final (t, c, off, cat) in rows) {
    final day = (today - off).clamp(1, 28);
    await db.insertRecord(
      Record(
        title: t,
        amount: m(c),
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
      amount: m(200000),
      date: d(today.clamp(1, 28), 10),
      note: lang == 'tr' ? 'ATM' : 'ATM',
    ),
  );
  final lent = await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Ali' : 'Alex',
      direction: DebtDirection.lent,
      amount: m(150000),
      date: d((today - 6).clamp(1, 28)),
      dueDate: DateTime(now.year, now.month + 1, 1),
      walletId: bank,
    ),
  );
  await db.insertDebtPayment(
    DebtPayment(
      debtId: lent,
      amount: m(50000),
      date: d((today - 1).clamp(1, 28), 20),
      walletId: cash,
    ),
  );
  await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Ayşe' : 'Emma',
      direction: DebtDirection.borrowed,
      amount: m(300000),
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
      amount: m(20000),
      date: DateTime(now.year, now.month - 1, 3),
      closed: true,
      closedAt: d((today - 2).clamp(1, 28), 11),
    ),
  );
  final kept = await db.insertDebt(
    Debt(
      person: lang == 'tr' ? 'Zeynep' : 'Mia',
      direction: DebtDirection.borrowed,
      amount: m(40000),
      date: DateTime(now.year, now.month - 1, 20),
      walletId: cash,
      closed: true,
      closedAt: d((today - 3).clamp(1, 28), 12),
    ),
  );
  await db.insertDebtPayment(
    DebtPayment(
      debtId: kept,
      amount: m(25000),
      date: DateTime(now.year, now.month - 1, 28),
      walletId: cash,
    ),
  );
  await db.insertRecurringRule(
    RecurringRule(
      title: lang == 'tr' ? 'Maaş' : 'Salary',
      amount: m(4500000),
      categoryId: id('Salary', 'Maaş'),
      startDate: DateTime(now.year, now.month, 1, 9),
    ),
  );
  await db.insertRecurringRule(
    RecurringRule(
      title: lang == 'tr' ? 'Kira' : 'Rent',
      amount: m(1800000),
      categoryId: id('Rent', 'Kira'),
      startDate: DateTime(now.year, now.month, 1, 10),
    ),
  );
  await db.insertRecurringRule(
    RecurringRule(
      title: 'Netflix',
      amount: lang == 'tr' ? 22999 : 1549,
      categoryId: id('Entertainment', 'Eğlence'),
      startDate: DateTime(now.year, now.month - 2, 15),
    ),
  );
  // A year of history, so charts over months have something to show; each
  // month a little different.
  const mood = [1.0, 0.85, 1.2, 0.95, 1.1, 0.8, 1.3, 0.9, 1.05, 1.15, 0.75];
  for (var back = 1; back <= 11; back++) {
    final f = mood[back - 1];
    DateTime day(int d) => DateTime(now.year, now.month - back, d, 12);
    for (final (title, cents, d, cat, w) in [
      (
        lang == 'tr' ? 'Maaş' : 'Salary',
        4500000,
        1,
        id('Salary', 'Maaş'),
        bank,
      ),
      (lang == 'tr' ? 'Kira' : 'Rent', 1800000, 1, id('Rent', 'Kira'), bank),
      (
        lang == 'tr' ? 'Market' : 'Groceries',
        (700000 * f).round(),
        9,
        id('Groceries', 'Market'),
        cash,
      ),
      (
        lang == 'tr' ? 'Faturalar' : 'Bills',
        (350000 * (2 - f)).round(),
        12,
        id('Bills', 'Faturalar'),
        bank,
      ),
      (
        lang == 'tr' ? 'Akşam yemeği' : 'Dinner',
        (400000 * f).round(),
        18,
        id('Eating out', 'Yeme-İçme'),
        cash,
      ),
      (
        lang == 'tr' ? 'Alışveriş' : 'Shopping',
        (650000 * f * f).round(),
        22,
        id('Shopping', 'Alışveriş'),
        bank,
      ),
      (
        lang == 'tr' ? 'Ulaşım' : 'Transport',
        200000,
        25,
        id('Transport', 'Ulaşım'),
        cash,
      ),
    ]) {
      await db.insertRecord(
        Record(
          title: title,
          amount: m(cents),
          date: day(d),
          categoryId: cat,
          walletId: w,
        ),
      );
    }
    // Cash spending comes from the bank.
    await db.insertTransfer(
      Transfer(
        fromWalletId: bank,
        toWalletId: cash,
        amount: m((1300000 * f).round()),
        date: day(5),
        note: 'ATM',
      ),
    );
  }
  // Reminders on, to show them in Settings.
  await db.setSetting(remindRecurringKey, '1');
  await db.setSetting(remindDebtsKey, '1');
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
    if (lang == 'en') await db.setSetting('currency', '\$');
    state = AppState(db);
    await state.load();
    await state.setLanguage(lang);
  });
  // flutter_test draws shadows as black outlines unless enabled.
  debugDisableShadows = false;
  // SHOT_HEIGHT=1920 gives 9:16 shots, the tallest Google Play accepts.
  final height =
      double.tryParse(Platform.environment['SHOT_HEIGHT'] ?? '') ?? 2340;
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('root'),
      child: YasbaApp(state: state),
    ),
  );
  return state;
}

/// Lets database work finish between frames.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
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
    testWidgets('welcome $lang', (tester) async {
      late AppState state;
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('welcome');
        final db = await AppDatabase.open(
          factory: databaseFactoryFfiNoIsolate,
          path: '${dir.path}/$lang.db',
          language: lang,
        );
        state = AppState(db);
        await state.load();
        await state.setLanguage(lang);
        if (lang == 'en') await state.setCurrency('\$');
      });
      final height =
          double.tryParse(Platform.environment['SHOT_HEIGHT'] ?? '') ?? 2340;
      tester.view.physicalSize = Size(1080, height);
      tester.view.devicePixelRatio = 3;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('root'),
          child: YasbaApp(state: state),
        ),
      );
      for (final (i, name) in [
        '0a_welcome',
        '0b_features',
        '0c_ready',
      ].indexed) {
        if (i > 0) {
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }
        await shot(tester, '${lang}_$name');
      }
      // Restore the default checked by the test framework.
      debugDisableShadows = true;
    });

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
      // A category's details.
      await tester.tap(
        find.textContaining(lang == 'tr' ? 'Kira' : 'Rent').last,
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await shot(tester, '${lang}_3d_category');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      // Bar chart, then the net.
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3c_stats_bars');
      await tester.tap(find.text('Net').first);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3e_stats_net');
      // Pick today's bar: its records are listed under the chart.
      {
        final rect = tester.getRect(find.byType(BarChart));
        final now = DateTime.now();
        final days = DateTime(now.year, now.month + 1, 0).day;
        // The amounts on the left take 40 pixels.
        final x = rect.left + 40 + (now.day - 0.5) * (rect.width - 40) / days;
        await tester.tapAt(Offset(x, rect.bottom - 40));
        await tester.pumpAndSettle();
        await shot(tester, '${lang}_3h_stats_day');
      }
      // Income and expenses apart, with the running total.
      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3i_net_split');
      await tester.tap(find.byIcon(Icons.trending_up));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3j_net_running');
      await tester.tap(
        find.descendant(
          of: find.byType(IconButton),
          matching: find.byIcon(Icons.account_balance_wallet),
        ),
      );
      await tester.pumpAndSettle();
      // The period picker, then the last three months, week by week.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_3f_periods');
      await tester.tap(find.text(lang == 'tr' ? 'Son 3 ay' : 'Last 3 months'));
      await settleDb(tester);
      await shot(tester, '${lang}_3g_last3_net');
      // A year of the net, with the running total.
      await tester.runAsync(
        () => state.setPeriod(Period.lastMonths(12, DateTime.now())),
      );
      await settleDb(tester);
      await shot(tester, '${lang}_3k_year_net');
      await tester.runAsync(() => state.setMonth(DateTime.now()));
      await tester.tap(find.text(lang == 'tr' ? 'Gider' : 'Expense').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(IconButton),
          matching: find.byIcon(Icons.pie_chart),
        ),
      );
      await settleDb(tester);
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
