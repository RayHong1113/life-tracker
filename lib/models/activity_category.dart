import 'package:flutter/material.dart';

class ActivityCategory {
  final String id;
  String name;
  IconData icon;
  Color color;
  int sortOrder;

  ActivityCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': icon.codePoint,
      'color': color.toARGB32(),
      'sort_order': sortOrder,
    };
  }

  factory ActivityCategory.fromMap(Map<String, dynamic> map) {
    return ActivityCategory(
      id: map['id'],
      name: map['name'],
      icon: IconData(map['icon_code'], fontFamily: 'MaterialIcons'),
      color: Color(map['color']),
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}