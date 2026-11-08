import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'wallet_avatar.dart';

/// Shows which wallet the page is filtered to, with ✕ to show all wallets
/// again. Wallets are chosen on the Wallets page.
class SelectedWalletChip extends StatelessWidget {
  const SelectedWalletChip({super.key});

  /// App bar bottom for [state]: the chip when a wallet is selected.
  static PreferredSizeWidget? bottomFor(AppState state) =>
      state.walletById(state.walletFilter) == null
      ? null
      : const PreferredSize(
          preferredSize: Size.fromHeight(44),
          child: SelectedWalletChip(),
        );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final wallet = state.walletById(state.walletFilter);
    if (wallet == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InputChip(
        avatar: WalletAvatar(wallet: wallet, radius: 12),
        label: Text(wallet.name),
        deleteButtonTooltipMessage: l.allWallets,
        onDeleted: () => state.setWalletFilter(null),
      ),
    );
  }
}
