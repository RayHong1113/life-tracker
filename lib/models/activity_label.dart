import 'package:flutter/material.dart';

class ActivityCategoryLabel {
  final String id;
  String name;
  String iconEmoji;
  Color color;
  int sortOrder;

  ActivityCategoryLabel({
    required this.id,
    required this.name,
    this.iconEmoji = '🏷️',
    this.color = const Color(0xFF1A73E8),
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_emoji': iconEmoji,
      'color': color.toARGB32(),
      'sort_order': sortOrder,
    };
  }

  factory ActivityCategoryLabel.fromMap(Map<String, dynamic> map) {
    Color parseColor(dynamic rawColor) {
      if (rawColor == null) return const Color(0xFF1A73E8);
      if (rawColor is int) return Color(rawColor);
      if (rawColor is String) {
        final parsed = int.tryParse(rawColor) ??
            int.tryParse(rawColor.replaceFirst('#', '0x')) ??
            int.tryParse('0xFF${rawColor.replaceFirst('#', '')}');
        if (parsed != null) return Color(parsed);
      }
      return const Color(0xFF1A73E8);
    }

    return ActivityCategoryLabel(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? 'Label',
      iconEmoji: map['icon_emoji']?.toString() ?? '🏷️',
      color: parseColor(map['color']),
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}
