import 'package:flutter/material.dart';

/// A place money is kept: cash, a bank account, a credit card...
class Wallet {
  final int? id;
  final String name;

  /// ARGB colour value.
  final int color;

  /// Icon key from [categoryIcons].
  final String icon;

  /// Balance before any record, in minor units. May be negative (debt).
  final int initialBalance;
  final bool archived;
  final int sortOrder;

  const Wallet({
    this.id,
    required this.name,
    required this.color,
    this.icon = 'bank',
    this.initialBalance = 0,
    this.archived = false,
    this.sortOrder = 0,
  });

  Color get colorValue => Color(color);

  Wallet copyWith({
    int? id,
    String? name,
    int? color,
    String? icon,
    int? initialBalance,
    bool? archived,
    int? sortOrder,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      initialBalance: initialBalance ?? this.initialBalance,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'color': color,
    'icon': icon,
    'initial_balance': initialBalance,
    'archived': archived ? 1 : 0,
    'sort_order': sortOrder,
  };

  factory Wallet.fromRow(Map<String, Object?> row) => Wallet(
    id: row['id'] as int?,
    name: row['name'] as String,
    color: row['color'] as int,
    icon: (row['icon'] as String?) ?? 'bank',
    initialBalance: row['initial_balance'] as int? ?? 0,
    archived: (row['archived'] as int? ?? 0) == 1,
    sortOrder: row['sort_order'] as int? ?? 0,
  );
}
