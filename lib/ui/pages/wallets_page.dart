import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../widgets/wallet_avatar.dart';
import 'edit_wallet_page.dart';

/// Wallet list with balances; one tab of [ManagePage].
class WalletsTab extends StatelessWidget {
  const WalletsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    Color amountColor(int v) => v < 0 ? scheme.error : scheme.onSurface;
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        ListTile(
          title: Text(
            l.totalBalance,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: Text(
            formatMoney(state.totalBalance, state.currency),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor(state.totalBalance),
            ),
          ),
        ),
        const Divider(),
        for (final w in state.wallets)
          ListTile(
            leading: Opacity(
              opacity: w.archived ? 0.4 : 1,
              child: WalletAvatar(wallet: w),
            ),
            title: Text(w.name),
            subtitle: w.archived ? Text(l.archived) : null,
            trailing: Text(
              formatMoney(state.balances[w.id] ?? 0, state.currency),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: amountColor(state.balances[w.id] ?? 0),
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EditWalletPage(wallet: w)),
            ),
          ),
      ],
    );
  }
}
