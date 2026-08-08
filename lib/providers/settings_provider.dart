import 'package:flutter/material.dart';
import '../services/database_helper.dart'; // 确认你的 DatabaseHelper 路径
import '../views/statistics/statistics_view.dart'; // 引入 TimeRange 定义所在文件

class SettingsProvider extends ChangeNotifier {
  TimeRange _timeRange = TimeRange.byMonth; // 默认值

  TimeRange get timeRange => _timeRange;

  /// 应用启动时加载所有配置
  Future<void> loadSettings() async {
    final savedRangeStr = await DatabaseHelper.instance.getSetting('statistics_time_range');
    if (savedRangeStr != null) {
      _timeRange = TimeRange.values.firstWhere(
        (e) => e.name == savedRangeStr,
        orElse: () => TimeRange.byMonth,
      );
      notifyListeners();
    }
  }

  /// 更新并保存 TimeRange
  Future<void> setTimeRange(TimeRange range) async {
    if (_timeRange == range) return;
    _timeRange = range;
    notifyListeners();
    
    // 持久化到 SQLite
    await DatabaseHelper.instance.saveSetting('statistics_time_range', range.name);
  }
}