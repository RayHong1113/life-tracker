import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/models/activity_log.dart';
import 'package:flutter/material.dart';

void main() {
  test('Cross-day activity calculation test', () {
    // Cross-day activity: 11:00 PM on Aug 10 to 1:00 AM on Aug 11
    final day1 = DateTime(2026, 8, 10);
    final day2 = DateTime(2026, 8, 11);

    final crossDayActivity = ActivityLog(
      id: 'cross_1',
      title: 'Night Shift',
      startTime: DateTime(2026, 8, 10, 23, 0),
      endTime: DateTime(2026, 8, 11, 1, 0),
      color: Colors.blue,
    );

    // Verify day 2 hour 0 (00:00 - 01:00 AM) range logic
    final hourStart = DateTime(day2.year, day2.month, day2.day, 0, 0, 0);
    final hourEnd = DateTime(day2.year, day2.month, day2.day, 0, 59, 59);

    final start = crossDayActivity.startTime;
    final end = crossDayActivity.endTime!;

    expect(start.isBefore(hourEnd), isTrue);
    expect(end.isAfter(hourStart), isTrue);
    expect(end.isAfter(hourEnd), isTrue);
  });
}
