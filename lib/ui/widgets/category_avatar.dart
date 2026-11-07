import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../utils/category_icons.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.radius = 20});

  final Category? category;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final color = c?.colorValue ?? Colors.grey;
    final fg = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: c?.emoji != null
          ? Text(c!.emoji!, style: TextStyle(fontSize: radius * 0.9))
          : Icon(iconFor(c?.icon ?? 'category'), color: fg, size: radius),
    );
  }
}
