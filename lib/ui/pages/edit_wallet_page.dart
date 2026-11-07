import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/wallet.dart';
import '../../state/app_state.dart';
import '../../utils/category_icons.dart';
import '../../utils/money.dart';
import '../widgets/wallet_avatar.dart';

class EditWalletPage extends StatefulWidget {
  const EditWalletPage({super.key, this.wallet});

  final Wallet? wallet;

  @override
  State<EditWalletPage> createState() => _EditWalletPageState();
}

/// Parses a balance that may start with a minus sign (debt).
int? _parseBalance(String input) {
  final s = input.trim();
  if (s.isEmpty) return 0;
  final negative = s.startsWith('-');
  final cents = parseMoney(negative ? s.substring(1) : s);
  if (cents == null) return null;
  return negative ? -cents : cents;
}

String _balanceText(int cents) {
  if (cents == 0) return '';
  final text = (cents.abs() / 100).toStringAsFixed(2);
  return cents < 0 ? '-$text' : text;
}

class _EditWalletPageState extends State<EditWalletPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late int _color;
  late String _icon;
  late bool _archived;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _name = TextEditingController(text: w?.name ?? '');
    _balance = TextEditingController(
      text: _balanceText(w?.initialBalance ?? 0),
    );
    _color = w?.color ?? categoryColors[5];
    _icon = w?.icon ?? 'bank';
    _archived = w?.archived ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Wallet get _draft => Wallet(
    id: widget.wallet?.id,
    name: _name.text.trim(),
    color: _color,
    icon: _icon,
    initialBalance: _parseBalance(_balance.text) ?? 0,
    archived: _archived,
    sortOrder: widget.wallet?.sortOrder ?? 0,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().saveWallet(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final w = widget.wallet!;
    if (state.wallets.length <= 1) {
      messenger.showSnackBar(SnackBar(content: Text(l.lastWallet)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteWalletQuestion(w.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await state.deleteWallet(w)) {
      messenger.showSnackBar(SnackBar(content: Text(l.walletInUse)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editWallet : l.newWallet),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: WalletAvatar(wallet: _draft, radius: 36)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.name,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return l.nameRequired;
                if (state.walletNameTaken(name, exceptId: widget.wallet?.id)) {
                  return l.nameTaken;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l.startingBalance,
                helperText: l.startingBalanceHint,
                suffixText: state.currency,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  _parseBalance(v ?? '') == null ? l.invalidBalance : null,
            ),
            const SizedBox(height: 24),
            Text(l.colour, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in categoryColors)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(color),
                      child: color == _color
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.icon, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in categoryIcons.entries)
                  IconButton.outlined(
                    isSelected: entry.key == _icon,
                    icon: Icon(entry.value),
                    onPressed: () => setState(() => _icon = entry.key),
                  ),
              ],
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.archive),
                subtitle: Text(l.walletArchiveHint),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
