import 'package:flutter/material.dart';

class ActivityLog {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;
  final Color color;
  final String? labelId;
  final String? labelName;
  final List<String> labelNames;

  ActivityLog({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description = '',
    this.color = const Color(0xFF1A73E8),
    this.labelId,
    this.labelName,
    this.labelNames = const [],
  });

  Map<String, dynamic> toMap() {
    final mergedLabels = Set<String>.from(labelNames);
    if (labelName != null && labelName!.isNotEmpty) {
      mergedLabels.add(labelName!);
    }

    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'description': description,
      'color': color.toARGB32(),
      'label_id': labelId,
      'label_name': labelName ?? (mergedLabels.isNotEmpty ? mergedLabels.first : null),
      'label_names': mergedLabels.join(';;;'),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
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

    DateTime parseDate(dynamic rawDate) {
      if (rawDate == null) return DateTime.now();
      if (rawDate is DateTime) {
        return DateTime(
          rawDate.year,
          rawDate.month,
          rawDate.day,
          rawDate.hour,
          rawDate.minute,
          rawDate.second,
          rawDate.millisecond,
        );
      }
      final str = rawDate.toString().trim();
      // Strip trailing 'Z' or timezone offset (+HH:MM / -HH:MM) so wall-clock
      // calendar time is preserved consistently across timezones and cloud sync.
      final wallClockStr = str.replaceFirst(
        RegExp(r'(Z|[+-]\d{2}:?\d{2})$'),
        '',
      );
      final parsed = DateTime.tryParse(wallClockStr) ?? DateTime.tryParse(str);
      if (parsed == null) return DateTime.now();
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      );
    }

    List<String> parseLabels() {
      final Set<String> list = {};
      final rawNames = map['label_names']?.toString();
      if (rawNames != null && rawNames.isNotEmpty) {
        final parts = rawNames.contains(';;;')
            ? rawNames.split(';;;')
            : rawNames.split(',');
        for (var p in parts) {
          if (p.trim().isNotEmpty) list.add(p.trim());
        }
      }
      final singleName = map['label_name']?.toString();
      if (singleName != null && singleName.isNotEmpty) {
        list.add(singleName.trim());
      }
      return list.toList();
    }

    final parsedLabelList = parseLabels();

    return ActivityLog(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? 'Activity',
      startTime: parseDate(map['start_time']),
      endTime: map['end_time'] != null ? parseDate(map['end_time']) : null,
      description: map['description']?.toString() ?? '',
      color: parseColor(map['color']),
      labelId: map['label_id']?.toString(),
      labelName: map['label_name']?.toString() ?? (parsedLabelList.isNotEmpty ? parsedLabelList.first : null),
      labelNames: parsedLabelList,
    );
  }

  Duration get duration {
    final end = endTime ??
        DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
          startTime.hour + 1,
          startTime.minute,
          startTime.second,
          startTime.millisecond,
        );
    final startUtc = DateTime.utc(
      startTime.year,
      startTime.month,
      startTime.day,
      startTime.hour,
      startTime.minute,
      startTime.second,
      startTime.millisecond,
    );
    final endUtc = DateTime.utc(
      end.year,
      end.month,
      end.day,
      end.hour,
      end.minute,
      end.second,
      end.millisecond,
    );
    return endUtc.difference(startUtc);
  }
}
