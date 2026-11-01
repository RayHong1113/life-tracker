import 'package:flutter/material.dart';
import '../../../models/activity_log.dart';
import '../../../models/activity_category.dart';
import '../models/positioned_activity.dart';

class TimelineLayoutHelper {
  /// Layout constants for the timeline grid
  static const double hourHeight = 70.0;
  static const double timeLabelWidth = 50.0;
  static const double cellHorizontalMargin = 2.0;

  /// Calculates collision-free multi-column positions for all activities on a day.
  static List<PositionedActivity> calculateOverlapPositions(
      List<ActivityLog> activities) {
    if (activities.isEmpty) return [];

    final sorted = activities.map((a) => PositionedActivity(a)).toList()
      ..sort((a, b) => a.activity.startTime.compareTo(b.activity.startTime));

    final groups = <List<PositionedActivity>>[];
    List<PositionedActivity> currentGroup = [];
    DateTime? groupEnd;

    for (var pos in sorted) {
      final start = pos.activity.startTime;
      final end = pos.activity.endTime ??
          DateTime(
            start.year,
            start.month,
            start.day,
            start.hour + 1,
            start.minute,
            start.second,
          );

      if (currentGroup.isEmpty) {
        currentGroup.add(pos);
        groupEnd = end;
      } else if (start.isBefore(groupEnd!)) {
        currentGroup.add(pos);
        if (end.isAfter(groupEnd)) groupEnd = end;
      } else {
        groups.add(currentGroup);
        currentGroup = [pos];
        groupEnd = end;
      }
    }
    if (currentGroup.isNotEmpty) groups.add(currentGroup);

    for (var group in groups) {
      final List<DateTime> columnEndTimes = [];

      for (var pos in group) {
        final start = pos.activity.startTime;
        final end = pos.activity.endTime ??
            DateTime(
              start.year,
              start.month,
              start.day,
              start.hour + 1,
              start.minute,
              start.second,
            );

        int assignedColumn = -1;

        for (int c = 0; c < columnEndTimes.length; c++) {
          if (!start.isBefore(columnEndTimes[c])) {
            assignedColumn = c;
            columnEndTimes[c] = end;
            break;
          }
        }

        if (assignedColumn == -1) {
          assignedColumn = columnEndTimes.length;
          columnEndTimes.add(end);
        }

        pos.column = assignedColumn;
      }

      final maxCols = columnEndTimes.length;
      for (var pos in group) {
        pos.totalColumns = maxCols;
      }
    }

    return sorted;
  }

  /// Calculates the maximum occupied minute offset (0-60) for a specific hour.
  static int getOccupiedMinutesInHour(
      DateTime targetDate, int hour, List<ActivityLog> dayActivities) {
    int maxEndMinute = 0;

    final hourStart =
        DateTime(targetDate.year, targetDate.month, targetDate.day, hour, 0, 0);
    final hourEnd = DateTime(
        targetDate.year, targetDate.month, targetDate.day, hour + 1, 0, 0);

    for (var activity in dayActivities) {
      final start = activity.startTime;
      final end = activity.endTime ??
          DateTime(
            start.year,
            start.month,
            start.day,
            start.hour + 1,
            start.minute,
            start.second,
          );

      if (start.isBefore(hourEnd) && end.isAfter(hourStart)) {
        if (!end.isBefore(hourEnd)) {
          maxEndMinute = 60;
        } else if (end.year == targetDate.year &&
            end.month == targetDate.month &&
            end.day == targetDate.day &&
            end.hour == hour) {
          if (end.minute > maxEndMinute) {
            maxEndMinute = end.minute;
          }
        }
      }
    }
    return maxEndMinute;
  }

  /// Finds the next best starting time starting from startHour.
  static DateTime getSmartStartTime(
      DateTime targetDate, int startHour, List<ActivityLog> dayActivities) {
    int currentHour = startHour;

    while (currentHour < 24) {
      final occupied =
          getOccupiedMinutesInHour(targetDate, currentHour, dayActivities);
      if (occupied < 60) {
        return DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          currentHour,
          occupied,
        );
      }
      currentHour++;
    }

    return DateTime(
        targetDate.year, targetDate.month, targetDate.day + 1, 0, 0);
  }

  /// Formats time as '12:30 PM' or '9:00 AM'.
  static String formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Matches activity to a category or returns an intelligent keyword fallback.
  static ActivityCategory getCategoryForActivity(
      ActivityLog activity, List<ActivityCategory> categories) {
    final actTitle = activity.title.trim().toLowerCase();
    for (var cat in categories) {
      if (cat.name.trim().toLowerCase() == actTitle) {
        return cat;
      }
    }

    IconData fallbackIcon = Icons.label_outline;
    if (actTitle.contains('code') || actTitle.contains('coding') || actTitle.contains('dev')) {
      fallbackIcon = Icons.code;
    } else if (actTitle.contains('work') || actTitle.contains('job')) {
      fallbackIcon = Icons.work_outline;
    } else if (actTitle.contains('study') || actTitle.contains('read') || actTitle.contains('book')) {
      fallbackIcon = Icons.school_outlined;
    } else if (actTitle.contains('workout') || actTitle.contains('gym') || actTitle.contains('fit') || actTitle.contains('sport')) {
      fallbackIcon = Icons.fitness_center;
    } else if (actTitle.contains('game') || actTitle.contains('play')) {
      fallbackIcon = Icons.sports_esports_outlined;
    } else if (actTitle.contains('cook') || actTitle.contains('food') || actTitle.contains('eat')) {
      fallbackIcon = Icons.restaurant;
    } else if (actTitle.contains('shop') || actTitle.contains('buy')) {
      fallbackIcon = Icons.shopping_bag_outlined;
    } else if (actTitle.contains('rest') || actTitle.contains('sleep') || actTitle.contains('nap')) {
      fallbackIcon = Icons.bedtime_outlined;
    }

    return ActivityCategory(
      id: '0',
      name: activity.title,
      icon: fallbackIcon,
      color: activity.color,
    );
  }
}
