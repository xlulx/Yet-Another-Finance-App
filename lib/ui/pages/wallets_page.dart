import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/wallet_avatar.dart';
import 'edit_wallet_page.dart';

/// Wallets with their balances; a page of the bottom navigation.
///
/// Tapping a wallet (or "All wallets") sets the wallet filter used by the
/// Records and Statistics pages, then calls [onWalletChosen] so the app can
/// switch to Records. Each wallet has an edit button.
class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key, this.onWalletChosen});

  final VoidCallback? onWalletChosen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Color amountColor(int v) => v < 0 ? scheme.error : scheme.onSurface;

    Future<void> choose(int? walletId) async {
      await state.setWalletFilter(walletId);
      onWalletChosen?.call();
    }

    Widget amount(int cents, {bool large = false}) => Text(
      formatMoney(cents, state.currency),
      style: (large ? text.titleMedium : text.bodyMedium)?.copyWith(
        fontWeight: FontWeight.w600,
        color: amountColor(cents),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.wallets)),
      floatingActionButton: FloatingActionButton(
        // Root pages stay alive side by side in the bottom navigation;
        // shared hero tags would clash when a new screen opens.
        heroTag: null,
        tooltip: l.addWallet,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditWalletPage())),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          ListTile(
            selected: state.walletFilter == null,
            selectedTileColor: scheme.secondaryContainer,
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.account_balance),
            ),
            title: Text(l.allWallets, style: text.titleMedium),
            subtitle: Text(l.totalBalance),
            trailing: Padding(
              // Line up with the amounts next to the edit buttons below.
              padding: const EdgeInsets.only(right: 48),
              child: amount(state.totalBalance, large: true),
            ),
            onTap: () => choose(null),
          ),
          const Divider(height: 1),
          for (final w in state.wallets)
            ListTile(
              selected: state.walletFilter == w.id,
              selectedTileColor: scheme.secondaryContainer,
              leading: Opacity(
                opacity: w.archived ? 0.4 : 1,
                child: WalletAvatar(wallet: w),
              ),
              title: Text(w.name),
              subtitle: w.archived ? Text(l.archived) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  amount(state.balances[w.id] ?? 0),
                  IconButton(
                    tooltip: l.editWallet,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditWalletPage(wallet: w),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => choose(w.id),
            ),
        ],
      ),
    );
  }
}
