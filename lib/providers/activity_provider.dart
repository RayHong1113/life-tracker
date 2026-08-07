import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../services/database_helper.dart';

class ActivityCategory {
  final String id;
  String name;
  IconData icon;
  Color color;

  ActivityCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': icon.codePoint,
      'color': color.toARGB32(),
    };
  }

  factory ActivityCategory.fromMap(Map<String, dynamic> map) {
    return ActivityCategory(
      id: map['id'],
      name: map['name'],
      icon: IconData(map['icon_code'], fontFamily: 'MaterialIcons'),
      color: Color(map['color']),
    );
  }
}

class ActivityProvider with ChangeNotifier {
  List<ActivityLog> _activities = [];
  DateTime _selectedDate = DateTime.now();

  final List<ActivityCategory> _categories = [
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
    // 💡 Provider 实例化时自动从 SQLite 读取数据
    fetchActivities();
  }

  List<ActivityLog> get activities => _activities;
  DateTime get selectedDate => _selectedDate;
  List<ActivityCategory> get categories => List.unmodifiable(_categories);

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // 从 SQLite 数据库读取所有活动
  Future<void> fetchActivities() async {
    _activities = await DatabaseHelper.instance.getAllActivities();
    notifyListeners();
  }

  // 从 SQLite 查指定日期的活动
  Future<List<ActivityLog>> getActivitiesForDate(DateTime date) async {
    return await DatabaseHelper.instance.getActivitiesForDate(date);
  }

  // 💡 增：同步写入 SQLite 磁盘
  Future<void> addActivity(ActivityLog activity) async {
    _activities.add(activity);
    notifyListeners();
    await DatabaseHelper.instance.insertActivity(activity);
  }

  // 💡 改：同步写入 SQLite 磁盘
  Future<void> updateActivity(ActivityLog activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index != -1) {
      _activities[index] = activity;
      notifyListeners();
      await DatabaseHelper.instance.updateActivity(activity);
    }
  }

  // 💡 删：同步从 SQLite 磁盘删除
  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteActivity(id);
  }

  void addCategory(ActivityCategory category) {
    _categories.add(category);
    notifyListeners();
  }

  void updateCategory(ActivityCategory category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}