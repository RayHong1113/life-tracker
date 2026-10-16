import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/providers/settings_provider.dart';
import 'package:life_tracker/views/statistics/utils/category_detail_helper.dart';
import 'dart:math';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Excluded Dates Tests', () {
    test('formatDateKey formats DateTime correctly as YYYY-MM-DD', () {
      final date1 = DateTime(2026, 10, 15);
      expect(SettingsProvider.formatDateKey(date1), equals('2026-10-15'));

      final date2 = DateTime(2026, 1, 5);
      expect(SettingsProvider.formatDateKey(date2), equals('2026-01-05'));
    });

    test('User Scenario: Sept 7-13 week with Sept 9-13 excluded calculates 2 effective days', () {
      final targetPeriodDate = DateTime(2026, 9, 7);
      // Case A: device clock in Oct 2026
      final todayA = DateTime(2026, 10, 15);
      // Case B: device clock in 2024
      final todayB = DateTime(2024, 10, 15);

      final excludedDates = {
        '2026-09-09',
        '2026-09-10',
        '2026-09-11',
        '2026-09-12',
        '2026-09-13',
      };

      for (var today in [todayA, todayB]) {
        final weekStart = CategoryDetailHelper.getStartOfWeek(targetPeriodDate);
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
        final isCurrentWeek = !today.isBefore(weekStart) && !today.isAfter(weekEnd);

        int activeDays = 7;
        int excludedCountInPeriod = 0;

        if (isCurrentWeek) {
          activeDays = today.difference(weekStart).inDays + 1;
          for (int i = 0; i < activeDays; i++) {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        } else {
          activeDays = 7;
          for (int i = 0; i < 7; i++) {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        }

        expect(activeDays, equals(7));
        expect(excludedCountInPeriod, equals(5));

        final effectiveDays = max(1, activeDays - excludedCountInPeriod);
        expect(effectiveDays, equals(2)); // Exactly Sept 7 and Sept 8

        const totalCategoryMinutes = 18 * 60 + 45; // 18h 45m = 1125 minutes
        final dailyAvgMinutes = (totalCategoryMinutes / effectiveDays).round();
        expect(dailyAvgMinutes, equals(563)); // 9h 23m
        expect(CategoryDetailHelper.formatDuration(Duration(minutes: dailyAvgMinutes)), equals('9h 23m'));
      }
    });

    test('Current in-progress month caps activeDays at elapsed days up to today', () {
      final targetPeriodDate = DateTime(2026, 10, 1);
      final today = DateTime(2026, 10, 15);

      final isCurrentMonth = today.year == targetPeriodDate.year && today.month == targetPeriodDate.month;
      expect(isCurrentMonth, isTrue);

      final activeDays = today.day;
      expect(activeDays, equals(15));

      final excludedDates = {'2026-10-03', '2026-10-04'};
      int excludedCount = 0;
      for (int i = 1; i <= activeDays; i++) {
        final day = DateTime(targetPeriodDate.year, targetPeriodDate.month, i);
        if (excludedDates.contains(SettingsProvider.formatDateKey(day))) {
          excludedCount++;
        }
      }

      expect(excludedCount, equals(2));
      final effectiveDays = max(1, activeDays - excludedCount);
      expect(effectiveDays, equals(13));

      const totalMinutes = 1560;
      final dailyAvg = (totalMinutes / effectiveDays).round();
      expect(dailyAvg, equals(120));
    });

    test('Completed past month uses all days in that month', () {
      final targetPeriodDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 10, 15);

      final daysInMonth = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 0).day;
      final isCurrentMonth = today.year == targetPeriodDate.year && today.month == targetPeriodDate.month;
      expect(isCurrentMonth, isFalse);

      final activeDays = daysInMonth;
      expect(activeDays, equals(30));
    });

    test('Effective days prevents zero division if all days are excluded', () {
      const activeDays = 7;
      const excludedCountInPeriod = 7;
      final effectiveDays = max(1, activeDays - excludedCountInPeriod);
      expect(effectiveDays, equals(1));
    });
  });
}
