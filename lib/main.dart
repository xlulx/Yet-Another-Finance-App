import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'l10n/app_localizations.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  // Only used to name the default categories on first launch.
  final systemLanguage = PlatformDispatcher.instance.locale.languageCode;
  final db = await AppDatabase.open(language: systemLanguage);
  final state = AppState(db);
  await state.load();
  runApp(YafaApp(state: state));
}

class YafaApp extends StatelessWidget {
  const YafaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D6B);
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'YAFA',
          debugShowCheckedModeBanner: false,
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // Dates and numbers follow the resolved app locale.
          builder: (context, child) {
            Intl.defaultLocale = Localizations.localeOf(context)
                .toLanguageTag();
            return child!;
          },
          theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: seed,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
