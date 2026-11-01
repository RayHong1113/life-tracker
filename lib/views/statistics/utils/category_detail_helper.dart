import '../../../models/activity_log.dart';
import '../models/category_detail_types.dart';

/// Helper methods for category detail screen calculations, period anchors, and label formatters.
class CategoryDetailHelper {
  /// Returns the start of the week (Monday at 00:00) for a given date.
  static DateTime getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
    return DateTime(
      date.year,
      date.month,
      date.day - (dayOfWeek - 1),
    );
  }

  /// Computes exact calendar days between [from] and [to] using UTC dates to avoid DST drift.
  static int daysBetween(DateTime from, DateTime to) {
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  /// Calculates the canonical anchor date for a given granularity.
  static DateTime getPeriodAnchor(
    DateTime date,
    CategoryDetailGranularity gran,
  ) {
    switch (gran) {
      case CategoryDetailGranularity.week:
        return getStartOfWeek(date);
      case CategoryDetailGranularity.month:
        return DateTime(date.year, date.month, 1);
      case CategoryDetailGranularity.year:
        return DateTime(date.year, 1, 1);
      case CategoryDetailGranularity.custom:
      case CategoryDetailGranularity.all:
        return DateTime(2026, 1, 1);
    }
  }

  /// Filters and extracts all available period anchors that contain recorded activity logs for this category.
  static List<DateTime> getAvailablePeriods(
    List<ActivityLog> allLogs,
    CategoryDetailGranularity gran,
    String categoryName,
    DateTime anchorDate,
  ) {
    final categoryLogs = allLogs
        .where(
          (act) =>
              act.title.trim().toLowerCase() ==
              categoryName.trim().toLowerCase(),
        )
        .expand(sliceActivityByDay)
        .toList();

    if (categoryLogs.isEmpty ||
        gran == CategoryDetailGranularity.all ||
        gran == CategoryDetailGranularity.custom) {
      return [getPeriodAnchor(anchorDate, gran)];
    }

    final Set<DateTime> periodSet = {};
    for (var log in categoryLogs) {
      periodSet.add(getPeriodAnchor(log.startTime, gran));
    }

    final list = periodSet.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  /// Formats the header label for the currently active period.
  static String formatPeriodLabel(
    DateTime date,
    CategoryDetailGranularity gran,
  ) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    switch (gran) {
      case CategoryDetailGranularity.week:
        final start = getStartOfWeek(date);
        final end = DateTime(start.year, start.month, start.day + 6);
        if (start.month == end.month) {
          return '${shortMonths[start.month - 1]} ${start.day} - ${end.day}';
        } else {
          return '${shortMonths[start.month - 1]} ${start.day} - ${shortMonths[end.month - 1]} ${end.day}';
        }
      case CategoryDetailGranularity.month:
        return '${months[date.month - 1]} ${date.year}';
      case CategoryDetailGranularity.year:
        return '${date.year}';
      case CategoryDetailGranularity.custom:
        return 'Custom Date Range';
      case CategoryDetailGranularity.all:
        return 'All Time History';
    }
  }

  /// Returns user-friendly label for granularity dropdown items.
  static String getGranularityDropdownLabel(CategoryDetailGranularity gran) {
    switch (gran) {
      case CategoryDetailGranularity.week:
        return 'By Week';
      case CategoryDetailGranularity.month:
        return 'By Month';
      case CategoryDetailGranularity.year:
        return 'By Year';
      case CategoryDetailGranularity.custom:
        return 'Custom Range';
      case CategoryDetailGranularity.all:
        return 'All Time';
    }
  }

  /// Formats duration into a readable string (e.g. '1h 30m' or '25m').
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Formats 24-hour time to 12-hour AM/PM string.
  static String formatTimeOfDay(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  /// Formats full date header for grouping activity logs (e.g. 'Friday, October 16, 2026').
  static String formatDateHeader(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final month = months[date.month - 1];
    return '$month ${date.day}';
  }

  /// Slices an activity crossing midnight into per-calendar-day slices.
  static List<ActivityLog> sliceActivityByDay(ActivityLog act) {
    final actStart = act.startTime;
    final actEnd = act.endTime ??
        DateTime(
          actStart.year,
          actStart.month,
          actStart.day,
          actStart.hour + 1,
          actStart.minute,
          actStart.second,
        );

    // If starts and ends on the same calendar day, no slicing needed
    if (actStart.year == actEnd.year &&
        actStart.month == actEnd.month &&
        actStart.day == actEnd.day) {
      return [act];
    }

    final slices = <ActivityLog>[];
    DateTime currentStart = actStart;

    while (currentStart.isBefore(actEnd)) {
      // Midnight of next calendar day (00:00:00)
      final nextMidnight = DateTime(
        currentStart.year,
        currentStart.month,
        currentStart.day + 1,
      );

      final currentEnd = actEnd.isBefore(nextMidnight) ? actEnd : nextMidnight;

      slices.add(ActivityLog(
        id: act.id,
        title: act.title,
        startTime: currentStart,
        endTime: currentEnd,
        description: act.description,
        color: act.color,
        labelId: act.labelId,
        labelName: act.labelName,
        labelNames: act.labelNames,
      ));

      currentStart = nextMidnight;
    }

    return slices;
  }
}
