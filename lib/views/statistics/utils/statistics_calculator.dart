import 'package:flutter/material.dart';
import '../../../models/activity_log.dart';
import '../../../models/activity_category.dart';
import '../models/category_stats.dart';

/// Calculation utility class handling date aggregation, objective time metrics, and duration formatting.
class StatisticsCalculator {
  /// Computes the normalized period anchor date for a given time range.
  static DateTime getPeriodAnchor(DateTime date, TimeRange selectedRange) {
    final clean = DateTime(date.year, date.month, date.day);
    switch (selectedRange) {
      case TimeRange.byDay:
        return clean;
      case TimeRange.byWeek:
        return DateTime(clean.year, clean.month, clean.day - (clean.weekday - 1));
      case TimeRange.byMonth:
        return DateTime(clean.year, clean.month, 1);
      case TimeRange.byYear:
        return DateTime(clean.year, 1, 1);
      case TimeRange.all:
        return DateTime(2026, 1, 1);
    }
  }

  /// Extracts all active periods containing actual activity logs, current date, or calendar selection.
  static List<DateTime> getAvailablePeriods(
    List<ActivityLog> activities,
    TimeRange selectedRange,
    DateTime targetDate,
    DateTime? lastDate,
  ) {
    final targetAnchor = getPeriodAnchor(targetDate, selectedRange);
    final nowAnchor = getPeriodAnchor(DateTime.now(), selectedRange);

    if (selectedRange == TimeRange.all) {
      return [nowAnchor];
    }

    final Set<DateTime> periodSet = {nowAnchor, targetAnchor};
    if (lastDate != null) {
      periodSet.add(getPeriodAnchor(lastDate, selectedRange));
    }
    for (var act in activities) {
      periodSet.add(getPeriodAnchor(act.startTime, selectedRange));
      if (act.endTime != null) {
        final end = act.endTime!;
        final endMoment = (end.hour == 0 &&
                end.minute == 0 &&
                end.second == 0 &&
                end.isAfter(act.startTime))
            ? DateTime(end.year, end.month, end.day - 1)
            : end;
        periodSet.add(getPeriodAnchor(endMoment, selectedRange));
      }
    }

    final list = periodSet.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  /// Formats the header date range title based on the selected time range.
  static String getDateRangeTitle(DateTime anchorDate, TimeRange selectedRange) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    if (selectedRange == TimeRange.byDay) {
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekDays[anchorDate.weekday - 1]}, ${months[anchorDate.month - 1]} ${anchorDate.day}, ${anchorDate.year}';
    } else if (selectedRange == TimeRange.byWeek) {
      final weekStart = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day - (anchorDate.weekday - 1),
      );
      final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

      if (weekStart.month == weekEnd.month) {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
      } else {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}, ${weekStart.year}';
      }
    } else if (selectedRange == TimeRange.byMonth) {
      final fullMonths = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${fullMonths[anchorDate.month - 1]} ${anchorDate.year}';
    } else if (selectedRange == TimeRange.byYear) {
      return '${anchorDate.year}';
    } else {
      return 'All Time History';
    }
  }

  /// Calculates total fixed objective minutes for the given period.
  static int calculateObjectiveMinutes(
    DateTime anchorDate,
    TimeRange selectedRange,
    List<ActivityLog> activities,
  ) {
    if (selectedRange == TimeRange.byDay) {
      return 24 * 60;
    } else if (selectedRange == TimeRange.byWeek) {
      return 7 * 24 * 60;
    } else if (selectedRange == TimeRange.byMonth) {
      final daysInMonth = DateTime(anchorDate.year, anchorDate.month + 1, 0).day;
      return daysInMonth * 24 * 60;
    } else if (selectedRange == TimeRange.byYear) {
      final isLeapYear = (anchorDate.year % 4 == 0 && anchorDate.year % 100 != 0) ||
          (anchorDate.year % 400 == 0);
      return (isLeapYear ? 366 : 365) * 24 * 60;
    } else {
      if (activities.isEmpty) return 24 * 60;
      final earliest =
          activities.map((a) => a.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      final earliestUtc = DateTime.utc(earliest.year, earliest.month, earliest.day);
      final days = todayUtc.difference(earliestUtc).inDays + 1;
      return (days < 1 ? 1 : days) * 24 * 60;
    }
  }

  /// Slices activities overlapping the active time window and aggregates per-category metrics.
  static Map<String, CategoryStats> calculateStatsForPage(
    List<ActivityLog> activities,
    List<ActivityCategory> categories,
    DateTime anchorDate,
    TimeRange selectedRange,
  ) {
    final Map<String, CategoryStats> statsMap = {};

    DateTime? windowStart;
    DateTime? windowEnd;

    if (selectedRange == TimeRange.byDay) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, anchorDate.day, 0, 0, 0);
      windowEnd = DateTime(anchorDate.year, anchorDate.month, anchorDate.day + 1, 0, 0, 0);
    } else if (selectedRange == TimeRange.byWeek) {
      final weekStart = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day - (anchorDate.weekday - 1),
      );
      windowStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
      windowEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    } else if (selectedRange == TimeRange.byMonth) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, 1);
      windowEnd = DateTime(anchorDate.year, anchorDate.month + 1, 1);
    } else if (selectedRange == TimeRange.byYear) {
      windowStart = DateTime(anchorDate.year, 1, 1);
      windowEnd = DateTime(anchorDate.year + 1, 1, 1);
    } else {
      windowStart = null;
      windowEnd = null;
    }

    for (var activity in activities) {
      final actStart = activity.startTime;
      final actEnd = activity.endTime ??
          DateTime(
            actStart.year,
            actStart.month,
            actStart.day,
            actStart.hour + 1,
            actStart.minute,
            actStart.second,
          );

      if (windowStart != null && windowEnd != null) {
        if (actEnd.isBefore(windowStart) ||
            actStart.isAfter(windowEnd) ||
            actEnd.isAtSameMomentAs(windowStart) ||
            actStart.isAtSameMomentAs(windowEnd)) {
          continue;
        }
      }

      final effectiveStart = (windowStart != null && actStart.isBefore(windowStart))
          ? windowStart
          : actStart;
      final effectiveEnd = (windowEnd != null && actEnd.isAfter(windowEnd))
          ? windowEnd
          : actEnd;

      // Compute wall-clock duration via UTC components so DST changes never distort hours
      final effectiveStartUtc = DateTime.utc(
        effectiveStart.year,
        effectiveStart.month,
        effectiveStart.day,
        effectiveStart.hour,
        effectiveStart.minute,
        effectiveStart.second,
        effectiveStart.millisecond,
      );
      final effectiveEndUtc = DateTime.utc(
        effectiveEnd.year,
        effectiveEnd.month,
        effectiveEnd.day,
        effectiveEnd.hour,
        effectiveEnd.minute,
        effectiveEnd.second,
        effectiveEnd.millisecond,
      );
      final overlapDuration = effectiveEndUtc.difference(effectiveStartUtc);
      if (overlapDuration.inMinutes <= 0) continue;

      final category = categories.firstWhere(
        (cat) => cat.name.trim().toLowerCase() == activity.title.trim().toLowerCase(),
        orElse: () => ActivityCategory(
          id: activity.title,
          name: activity.title,
          icon: Icons.task_alt,
          color: activity.color,
        ),
      );

      if (statsMap.containsKey(category.name)) {
        statsMap[category.name]!.totalDuration += overlapDuration;
        statsMap[category.name]!.count += 1;
      } else {
        statsMap[category.name] = CategoryStats(
          category: category,
          totalDuration: overlapDuration,
          count: 1,
        );
      }
    }

    return statsMap;
  }

  /// Formats duration into a human-readable string (e.g. '2h 15m' or '45m').
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Returns user-friendly text label for each TimeRange enum value.
  static String getTimeRangeLabel(TimeRange range) {
    switch (range) {
      case TimeRange.byDay:
        return 'By Day';
      case TimeRange.byWeek:
        return 'By Week';
      case TimeRange.byMonth:
        return 'By Month';
      case TimeRange.byYear:
        return 'By Year';
      case TimeRange.all:
        return 'All Time';
    }
  }
}
