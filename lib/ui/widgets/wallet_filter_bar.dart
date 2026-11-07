import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'wallet_avatar.dart';

/// "All wallets" plus one chip per active wallet. Hidden when there is only
/// one wallet, since filtering would change nothing.
class WalletFilterBar extends StatelessWidget {
  const WalletFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final wallets = state.wallets
        .where((w) => !w.archived || w.id == state.walletFilter)
        .toList();
    if (state.wallets.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l.allWallets),
              selected: state.walletFilter == null,
              onSelected: (_) => state.setWalletFilter(null),
            ),
          ),
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: WalletAvatar(wallet: w, radius: 12),
                label: Text(w.name),
                selected: state.walletFilter == w.id,
                onSelected: (_) => state.setWalletFilter(w.id),
              ),
            ),
        ],
      ),
    );
  }
}
