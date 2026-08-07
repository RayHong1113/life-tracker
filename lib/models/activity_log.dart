import 'package:flutter/material.dart';

class ActivityLog {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;
  final Color color;

  ActivityLog({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description = '',
    this.color = const Color(0xFF1A73E8),
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'description': description,
      'color': color.toARGB32(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      title: map['title'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      description: map['description'] ?? '',
      color: map['color'] != null
          ? Color(map['color'])
          : const Color(0xFF1A73E8),
    );
  }
}