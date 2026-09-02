import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../views/statistics/statistics_view.dart';
import '../views/statistics/category_detail_screen.dart';

class SettingsProvider extends ChangeNotifier {
  TimeRange _timeRange = TimeRange.byMonth;
  bool _autoCloudSync = true;
  CategoryDetailGranularity _categoryDetailGranularity = CategoryDetailGranularity.week;

  TimeRange get timeRange => _timeRange;
  bool get autoCloudSync => _autoCloudSync;
  CategoryDetailGranularity get categoryDetailGranularity => _categoryDetailGranularity;

  /// Load settings at app startup
  Future<void> loadSettings() async {
    final savedRangeStr =
        await DatabaseHelper.instance.getSetting('statistics_time_range');
    if (savedRangeStr != null) {
      _timeRange = TimeRange.values.firstWhere(
        (e) => e.name == savedRangeStr,
        orElse: () => TimeRange.byMonth,
      );
    }

    final savedGranStr =
        await DatabaseHelper.instance.getSetting('category_detail_granularity');
    if (savedGranStr != null) {
      _categoryDetailGranularity = CategoryDetailGranularity.values.firstWhere(
        (e) => e.name == savedGranStr,
        orElse: () => CategoryDetailGranularity.week,
      );
    } else {
      _categoryDetailGranularity = CategoryDetailGranularity.week;
    }

    final autoSyncStr =
        await DatabaseHelper.instance.getSetting('auto_cloud_sync');
    if (autoSyncStr != null) {
      _autoCloudSync = autoSyncStr == 'true';
    } else {
      _autoCloudSync = true;
      await DatabaseHelper.instance.saveSetting('auto_cloud_sync', 'true');
    }

    notifyListeners();
  }

  /// Update and persist Auto Cloud Sync setting
  Future<void> setAutoCloudSync(bool val) async {
    _autoCloudSync = val;
    notifyListeners();
    await DatabaseHelper.instance
        .saveSetting('auto_cloud_sync', val.toString());
  }

  /// Update and persist TimeRange
  Future<void> setTimeRange(TimeRange range) async {
    if (_timeRange == range) return;
    _timeRange = range;
    notifyListeners();
    await DatabaseHelper.instance
        .saveSetting('statistics_time_range', range.name);
  }

  /// Update and persist CategoryDetailGranularity
  Future<void> setCategoryDetailGranularity(CategoryDetailGranularity gran) async {
    if (_categoryDetailGranularity == gran) return;
    _categoryDetailGranularity = gran;
    notifyListeners();
    await DatabaseHelper.instance
        .saveSetting('category_detail_granularity', gran.name);
  }
}