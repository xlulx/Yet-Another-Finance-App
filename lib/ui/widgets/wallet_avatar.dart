import 'package:flutter/material.dart';

import '../../models/wallet.dart';
import '../../utils/category_icons.dart';

class WalletAvatar extends StatelessWidget {
  const WalletAvatar({super.key, required this.wallet, this.radius = 20});

  final Wallet? wallet;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = wallet?.colorValue ?? Colors.grey;
    final fg = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(iconFor(wallet?.icon ?? 'bank'), color: fg, size: radius),
    );
  }
}
