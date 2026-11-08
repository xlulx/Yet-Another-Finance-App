import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

import 'pages/records_page.dart';
import 'pages/stats_page.dart';
import 'pages/wallets_page.dart';
import 'widgets/app_drawer.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Records, in the middle, is where the app opens.
  int _index = 1;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Check for a due automatic backup whenever the app comes back.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<AppState>().onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      // Here rather than on each page, so it also covers the bottom bar.
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _index,
        children: [
          // Choosing a wallet shows its records.
          WalletsPage(onWalletChosen: () => setState(() => _index = 1)),
          const RecordsPage(),
          const StatsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l.wallets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l.navRecords,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: l.navStats,
          ),
        ],
      ),
    );
  }
}
