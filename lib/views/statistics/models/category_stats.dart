import '../../../models/activity_category.dart';

/// Supported statistical time ranges for data aggregation.
enum TimeRange { byDay, byWeek, byMonth, byYear, all }

/// Visual chart modes: percentage of logged time vs percentage of total objective time.
enum ChartMode { loggedTime, objectiveTime }

/// Aggregated statistical data container for a single category.
class CategoryStats {
  final ActivityCategory category;
  Duration totalDuration;
  int count;

  CategoryStats({
    required this.category,
    required this.totalDuration,
    required this.count,
  });
}
