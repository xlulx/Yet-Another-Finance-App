import 'package:flutter/material.dart';

/// Kategori türü. Sıra (index) veritabanında saklanır; sadece sona ekleyin.
enum CategoryType { expense, income }

class Category {
  final int? id;
  final String name;
  final CategoryType type;

  /// ARGB renk değeri.
  final int color;

  /// [CategoryIcons.all] içindeki ikon anahtarı.
  final String icon;

  /// Doluysa ikon yerine emoji gösterilir.
  final String? emoji;
  final bool archived;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    this.icon = 'category',
    this.emoji,
    this.archived = false,
    this.sortOrder = 0,
  });

  Color get colorValue => Color(color);

  Category copyWith({
    int? id,
    String? name,
    CategoryType? type,
    int? color,
    String? icon,
    String? emoji,
    bool clearEmoji = false,
    bool? archived,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'type': type.index,
    'color': color,
    'icon': icon,
    'emoji': emoji,
    'archived': archived ? 1 : 0,
    'sort_order': sortOrder,
  };

  factory Category.fromRow(Map<String, Object?> row) => Category(
    id: row['id'] as int?,
    name: row['name'] as String,
    type: CategoryType.values[row['type'] as int],
    color: row['color'] as int,
    icon: (row['icon'] as String?) ?? 'category',
    emoji: row['emoji'] as String?,
    archived: (row['archived'] as int? ?? 0) == 1,
    sortOrder: row['sort_order'] as int? ?? 0,
  );
}
