import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../views/statistics/statistics_view.dart';
import '../views/statistics/category_detail_screen.dart';

class SettingsProvider extends ChangeNotifier {
  TimeRange _timeRange = TimeRange.byMonth;
  bool _autoCloudSync = true;
  CategoryDetailGranularity _categoryDetailGranularity = CategoryDetailGranularity.week;
  Set<String> _excludedDates = {};

  TimeRange get timeRange => _timeRange;
  bool get autoCloudSync => _autoCloudSync;
  CategoryDetailGranularity get categoryDetailGranularity => _categoryDetailGranularity;
  Set<String> get excludedDates => _excludedDates;

  /// Utility to format a DateTime into 'YYYY-MM-DD' key string
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

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

    final excludedStr =
        await DatabaseHelper.instance.getSetting('excluded_dates');
    if (excludedStr != null && excludedStr.isNotEmpty) {
      try {
        final list = jsonDecode(excludedStr) as List<dynamic>;
        _excludedDates = list.map((e) => e.toString()).toSet();
      } catch (_) {
        _excludedDates = {};
      }
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

  /// Add a single date to excluded untracked dates list
  Future<bool> addExcludedDate(DateTime date) async {
    final key = formatDateKey(date);
    if (_excludedDates.add(key)) {
      notifyListeners();
      await _saveExcludedDates();
      return true;
    }
    return false;
  }

  /// Add a date range to excluded untracked dates list
  Future<int> addExcludedDateRange(DateTime start, DateTime end) async {
    int addedCount = 0;
    DateTime curr = DateTime(start.year, start.month, start.day);
    final endClean = DateTime(end.year, end.month, end.day);
    while (!curr.isAfter(endClean)) {
      if (_excludedDates.add(formatDateKey(curr))) {
        addedCount++;
      }
      curr = curr.add(const Duration(days: 1));
    }
    if (addedCount > 0) {
      notifyListeners();
      await _saveExcludedDates();
    }
    return addedCount;
  }

  /// Remove an excluded date by its key
  Future<void> removeExcludedDate(String key) async {
    if (_excludedDates.remove(key)) {
      notifyListeners();
      await _saveExcludedDates();
    }
  }

  /// Clear all excluded dates
  Future<void> clearAllExcludedDates() async {
    if (_excludedDates.isNotEmpty) {
      _excludedDates.clear();
      notifyListeners();
      await _saveExcludedDates();
    }
  }

  /// Persist excluded dates to local database storage
  Future<void> _saveExcludedDates() async {
    final jsonString = jsonEncode(_excludedDates.toList());
    await DatabaseHelper.instance.saveSetting('excluded_dates', jsonString);
  }
}