import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../models/activity_category.dart';
import '../services/database_helper.dart';

class ActivityProvider with ChangeNotifier {
  List<ActivityLog> _activities = [];
  List<ActivityCategory> _categories = [];
  DateTime _selectedDate = DateTime.now();

  // 默认初始分类列表
  final List<ActivityCategory> _defaultCategories = [
    ActivityCategory(id: '1', name: 'Coding', icon: Icons.code, color: const Color(0xFF1A73E8)),
    ActivityCategory(id: '2', name: 'Work', icon: Icons.work_outline, color: const Color(0xFFD93025)),
    ActivityCategory(id: '3', name: 'Study', icon: Icons.school_outlined, color: const Color(0xFF188038)),
    ActivityCategory(id: '4', name: 'Workout', icon: Icons.fitness_center, color: const Color(0xFFF9AB00)),
    ActivityCategory(id: '5', name: 'Gaming', icon: Icons.sports_esports_outlined, color: const Color(0xFFA142F4)),
    ActivityCategory(id: '6', name: 'Cooking', icon: Icons.restaurant, color: const Color(0xFFE52592)),
    ActivityCategory(id: '7', name: 'Shopping', icon: Icons.shopping_bag_outlined, color: const Color(0xFF607D8B)),
    ActivityCategory(id: '8', name: 'Rest', icon: Icons.bedtime_outlined, color: Colors.teal),
  ];

  ActivityProvider() {
    _initData();
  }

  List<ActivityLog> get activities => _activities;
  DateTime get selectedDate => _selectedDate;
  List<ActivityCategory> get categories => List.unmodifiable(_categories);

  Future<void> _initData() async {
    await fetchCategories(); // 💡 优先加载分类
    await fetchActivities();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // ==================== Activity Logs ====================

  Future<void> fetchActivities() async {
    _activities = await DatabaseHelper.instance.getAllActivities();
    notifyListeners();
  }

  Future<List<ActivityLog>> getActivitiesForDate(DateTime date) async {
    return await DatabaseHelper.instance.getActivitiesForDate(date);
  }

  Future<void> addActivity(ActivityLog activity) async {
    _activities.add(activity);
    notifyListeners();
    await DatabaseHelper.instance.insertActivity(activity);
  }

  Future<void> updateActivity(ActivityLog activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index != -1) {
      _activities[index] = activity;
      notifyListeners();
      await DatabaseHelper.instance.updateActivity(activity);
    }
  }

  // 💡 删除指定 ActivityLog
  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteActivity(id);
  }

  // ==================== Categories (SQLite 持久化) ====================

  Future<void> fetchCategories() async {
    final dbCategories = await DatabaseHelper.instance.getAllCategories();
    
    if (dbCategories.isNotEmpty) {
      _categories = dbCategories;
    } else {
      // 首次安装无数据时，写入默认数据进 SQLite
      _categories = List.from(_defaultCategories);
      for (var cat in _defaultCategories) {
        await DatabaseHelper.instance.insertCategory(cat);
      }
    }
    notifyListeners();
  }

  Future<void> addCategory(ActivityCategory category) async {
    _categories.add(category);
    notifyListeners();
    await DatabaseHelper.instance.insertCategory(category);
  }

  Future<void> updateCategory(ActivityCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      final oldCategory = _categories[index];
      _categories[index] = category;
      
      notifyListeners();
      await DatabaseHelper.instance.updateCategory(category);

      // 💡 关键修复：去掉 || 颜色匹配！只通过旧分类名称（oldCategory.name）来精确寻找关联的日志
      for (var i = 0; i < _activities.length; i++) {
        if (_activities[i].title == oldCategory.name) {
          final updatedLog = ActivityLog(
            id: _activities[i].id,
            title: category.name,     // 更新为新名字
            startTime: _activities[i].startTime,
            endTime: _activities[i].endTime,
            description: _activities[i].description,
            color: category.color,     // 同步更新为新颜色
          );

          _activities[i] = updatedLog;
          await DatabaseHelper.instance.updateActivity(updatedLog);
        }
      }

      notifyListeners(); // 刷新 Calendar 和 Statistics 视图
    }
  }

  // 💡 联动删除：删除 Category 时，一并清理它名下的所有 ActivityLog
  Future<void> deleteCategory(String id) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final targetCategory = _categories[index];

    // 1. 从分类列表和数据库删除 Category
    _categories.removeAt(index);
    await DatabaseHelper.instance.deleteCategory(id);

    // 💡 关键修复：仅匹配 title == targetCategory.name，防止误杀同颜色的无关卡片
    final logsToRemove = _activities.where((a) =>
        a.title.toLowerCase() == targetCategory.name.toLowerCase()).toList();

    for (var log in logsToRemove) {
      _activities.removeWhere((a) => a.id == log.id);
      await DatabaseHelper.instance.deleteActivity(log.id);
    }

    notifyListeners();
  }
}