import 'package:flutter/material.dart';

import '../../models/wallet.dart';
import 'wallet_avatar.dart';

/// Picks a wallet. Archived wallets are only listed when already selected.
class WalletDropdown extends StatelessWidget {
  WalletDropdown({
    super.key,
    required this.label,
    required this.wallets,
    required this.value,
    required ValueChanged<int> onChanged,
    this.validator,
  }) : noneLabel = null,
       onSelected = ((v) {
         if (v != null) onChanged(v);
       });

  /// Also offers no wallet, labelled [noneLabel].
  const WalletDropdown.optional({
    super.key,
    required this.label,
    required this.wallets,
    required this.value,
    required String this.noneLabel,
    required this.onSelected,
  }) : validator = null;

  final String label;
  final List<Wallet> wallets;
  final int? value;
  final String? noneLabel;
  final ValueChanged<int?> onSelected;
  final FormFieldValidator<int?>? validator;

  @override
  Widget build(BuildContext context) {
    final items = wallets.where((w) => !w.archived || w.id == value);
    return DropdownButtonFormField<int?>(
      // Rebuild when the selection is changed from outside (e.g. swap).
      key: ValueKey('$label-$value'),
      initialValue: value,
      // Gives the items a bounded width, needed by the Flexible below.
      isExpanded: true,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (noneLabel != null)
          DropdownMenuItem(
            value: null,
            child: Text(noneLabel!, overflow: TextOverflow.ellipsis),
          ),
        for (final w in items)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                WalletAvatar(wallet: w, radius: 12),
                const SizedBox(width: 12),
                Flexible(child: Text(w.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: onSelected,
    );
  }
}
