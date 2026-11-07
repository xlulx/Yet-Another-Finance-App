import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final db = await AppDatabase.open();
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
      child: MaterialApp(
        title: 'YAFA',
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
