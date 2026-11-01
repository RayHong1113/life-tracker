import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/models/activity_log.dart';
import 'package:life_tracker/views/calendar/utils/timeline_layout_helper.dart';
import 'package:life_tracker/views/statistics/utils/category_detail_helper.dart';

void main() {
  group('Cross-Timezone & DST Calendar Stability Tests', () {
    test('ActivityLog.fromMap preserves wall-clock time across timezone suffixes', () {
      final mapWithZ = {
        'id': '1',
        'title': 'Coding',
        'start_time': '2026-11-01T01:30:00.000Z',
        'end_time': '2026-11-01T09:30:00.000Z',
      };
      final mapWithOffset = {
        'id': '2',
        'title': 'Rest',
        'start_time': '2026-11-01T22:15:00.000+08:00',
        'end_time': '2026-11-02T06:45:00.000+08:00',
      };

      final log1 = ActivityLog.fromMap(mapWithZ);
      expect(log1.startTime.isUtc, isFalse);
      expect(log1.startTime.year, 2026);
      expect(log1.startTime.month, 11);
      expect(log1.startTime.day, 1);
      expect(log1.startTime.hour, 1);
      expect(log1.startTime.minute, 30);
      expect(log1.duration.inMinutes, 8 * 60);

      final log2 = ActivityLog.fromMap(mapWithOffset);
      expect(log2.startTime.isUtc, isFalse);
      expect(log2.startTime.day, 1);
      expect(log2.startTime.hour, 22);
      expect(log2.startTime.minute, 15);
      expect(log2.endTime!.day, 2);
      expect(log2.endTime!.hour, 6);
      expect(log2.endTime!.minute, 45);
      expect(log2.duration.inMinutes, 8 * 60 + 30);
    });

    test('Wall-clock duration on DST transition days (Nov 1 & Mar 8) is exact', () {
      // DST Fall Back: Nov 1, 2026 (00:00 to 08:00 must be 8h, not 9h)
      final nov1Sleep = ActivityLog(
        id: 'dst_fall',
        title: 'Rest',
        startTime: DateTime(2026, 11, 1, 0, 0),
        endTime: DateTime(2026, 11, 1, 8, 0),
      );
      expect(nov1Sleep.duration.inMinutes, 480);

      // DST Spring Forward: Mar 8, 2026 (00:00 to 08:00 must be 8h, not 7h)
      final mar8Sleep = ActivityLog(
        id: 'dst_spring',
        title: 'Rest',
        startTime: DateTime(2026, 3, 8, 0, 0),
        endTime: DateTime(2026, 3, 8, 8, 0),
      );
      expect(mar8Sleep.duration.inMinutes, 480);
    });

    test('Calendar day difference across DST boundaries is exact', () {
      // Across Spring Forward (Mar 8, 2026)
      expect(
        CategoryDetailHelper.daysBetween(
          DateTime(2026, 3, 8),
          DateTime(2026, 3, 9),
        ),
        1,
      );
      // Across Fall Back (Nov 1, 2026)
      expect(
        CategoryDetailHelper.daysBetween(
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 2),
        ),
        1,
      );
      // Multi-month span across DST boundary
      final start = DateTime(2026, 3, 1);
      final target = DateTime(2026, 3, 1 + 15);
      expect(CategoryDetailHelper.daysBetween(start, target), 15);
    });

    test('TimelineLayoutHelper.getSmartStartTime advances to next calendar day on Nov 1', () {
      final nov1 = DateTime(2026, 11, 1);
      final fullDayLog = ActivityLog(
        id: 'full',
        title: 'Work',
        startTime: DateTime(2026, 11, 1, 0, 0),
        endTime: DateTime(2026, 11, 2, 0, 0),
      );
      final nextSmart = TimelineLayoutHelper.getSmartStartTime(
        nov1,
        23,
        [fullDayLog],
      );
      expect(nextSmart.year, 2026);
      expect(nextSmart.month, 11);
      expect(nextSmart.day, 2);
      expect(nextSmart.hour, 0);
    });
  });
}
