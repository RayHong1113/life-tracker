import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/activity_log.dart';
import '../models/activity_category.dart';
import '../models/activity_label.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

class ActivityProvider with ChangeNotifier {
  List<ActivityLog> _activities = [];
  List<ActivityCategory> _categories = List.from(_defaultCategories);
  List<ActivityCategoryLabel> _labels = List.from(_defaultLabels);
  DateTime _selectedDate = DateTime.now();

  // 默认初始分类列表
  static final List<ActivityCategory> _defaultCategories = [
    ActivityCategory(id: '1', name: 'Coding', icon: Icons.code, color: const Color(0xFF1A73E8)),
    ActivityCategory(id: '2', name: 'Work', icon: Icons.work_outline, color: const Color(0xFFD93025)),
    ActivityCategory(id: '3', name: 'Study', icon: Icons.school_outlined, color: const Color(0xFF188038)),
    ActivityCategory(id: '4', name: 'Workout', icon: Icons.fitness_center, color: const Color(0xFFF9AB00)),
    ActivityCategory(id: '5', name: 'Gaming', icon: Icons.sports_esports_outlined, color: const Color(0xFF3F51B5)),
    ActivityCategory(id: '6', name: 'Cooking', icon: Icons.restaurant, color: const Color(0xFFE52592)),
    ActivityCategory(id: '7', name: 'Shopping', icon: Icons.shopping_bag_outlined, color: const Color(0xFF607D8B)),
    ActivityCategory(id: '8', name: 'Rest', icon: Icons.bedtime_outlined, color: Colors.teal),
  ];

  // 默认初始标签列表 (LifeTracker 生活追踪风格：支持英文 + Emoji)
  static final List<ActivityCategoryLabel> _defaultLabels = [
    ActivityCategoryLabel(id: 'l1', name: '✍️ Writing', sortOrder: 0),
    ActivityCategoryLabel(id: 'l2', name: '🪥 Grooming', sortOrder: 1),
    ActivityCategoryLabel(id: 'l3', name: '🚿 Shower', sortOrder: 2),
    ActivityCategoryLabel(id: 'l4', name: '🚶 Walking', sortOrder: 3),
    ActivityCategoryLabel(id: 'l5', name: '🏋️ Dumbbell', sortOrder: 4),
    ActivityCategoryLabel(id: 'l6', name: '📚 Reading', sortOrder: 5),
    ActivityCategoryLabel(id: 'l7', name: '☕ Break', sortOrder: 6),
    ActivityCategoryLabel(id: 'l8', name: '🏃 Running', sortOrder: 7),
  ];

  bool _isOfficialFileRestoring = false;

  ActivityProvider() {
    _initData();
  }

  List<ActivityLog> get activities => _activities;
  DateTime get selectedDate => _selectedDate;
  List<ActivityCategory> get categories => List.unmodifiable(_categories);
  List<ActivityCategoryLabel> get labels => List.unmodifiable(_labels);

  Future<void> _initData() async {
    try {
      await CloudSyncService.instance.init();
      if (FirebaseService.instance.isSignedIn && !_isOfficialFileRestoring) {
        await FirebaseService.instance.pullCloudFirestoreToLocal();
      }
    } catch (e) {
      debugPrint('Cloud sync init error: $e');
    }
    await fetchCategories(); // 💡 优先加载分类
    await fetchLabels();     // 💡 加载标签
    await fetchActivities();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> _autoSyncToFirebase() async {
    if (FirebaseService.instance.isSignedIn && !_isOfficialFileRestoring) {
      await FirebaseService.instance.syncFullFirestore();
    }
  }

  // ==================== Activity Logs ====================

  Future<void> fetchActivities() async {
    _activities = await DatabaseHelper.instance.getAllActivities();
    notifyListeners();
  }

  Future<List<ActivityLog>> getActivitiesForDate(DateTime date) async {
    return getActivitiesForDateSync(date);
  }

  List<ActivityLog> getActivitiesForDateSync(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day + 1, 0, 0, 0);

    return _activities.where((activity) {
      final start = activity.startTime;
      final end = activity.endTime ?? DateTime(start.year, start.month, start.day, start.hour + 1, start.minute, start.second);

      return start.isBefore(dayEnd) && end.isAfter(dayStart);
    }).toList();
  }

  Future<void> addActivity(ActivityLog activity) async {
    _activities.add(activity);
    notifyListeners();
    await DatabaseHelper.instance.insertActivity(activity);
    _autoSyncToFirebase();
  }

  Future<void> updateActivity(ActivityLog activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index != -1) {
      _activities[index] = activity;
      notifyListeners();
      await DatabaseHelper.instance.updateActivity(activity);
      _autoSyncToFirebase();
    }
  }

  // 💡 删除指定 ActivityLog
  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteActivity(id);
    await FirebaseService.instance.deleteFirestoreActivity(id);
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
    category.sortOrder = _categories.length;
    _categories.add(category);
    notifyListeners();
    await DatabaseHelper.instance.insertCategory(category);
    _autoSyncToFirebase();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);

    for (int i = 0; i < _categories.length; i++) {
      _categories[i].sortOrder = i;
    }

    notifyListeners();
    await DatabaseHelper.instance.updateCategoryOrders(_categories);
    _autoSyncToFirebase();
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
      _autoSyncToFirebase();
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
    await FirebaseService.instance.deleteFirestoreCategory(id);

    // 💡 关键修复：仅匹配 title == targetCategory.name，防止误杀同颜色的无关卡片
    final logsToRemove = _activities.where((a) =>
        a.title.toLowerCase() == targetCategory.name.toLowerCase()).toList();

    for (var log in logsToRemove) {
      _activities.removeWhere((a) => a.id == log.id);
      await DatabaseHelper.instance.deleteActivity(log.id);
      await FirebaseService.instance.deleteFirestoreActivity(log.id);
    }

    notifyListeners();
  }

  // ==================== Labels (Spendee 风格标签) ====================

  Future<void> fetchLabels() async {
    final dbLabels = await DatabaseHelper.instance.getAllLabels();
    if (dbLabels.isNotEmpty) {
      _labels = dbLabels;
      final legacyMap = {
        '🍎 Fruit': '✍️ Writing',
        '🥩 Beef': '🪥 Grooming',
        '🥬 Vegetable': '🚿 Shower',
        '🐟 SeaFood': '🚶 Walking',
        'Vegetable': '🚿 Shower',
      };
      for (var l in List<ActivityCategoryLabel>.from(_labels)) {
        if (legacyMap.containsKey(l.name)) {
          final newName = legacyMap[l.name]!;
          final updated = ActivityCategoryLabel(id: l.id, name: newName, sortOrder: l.sortOrder);
          await updateLabel(updated);
        }
      }
    } else {
      _labels = List.from(_defaultLabels);
      for (var l in _defaultLabels) {
        await DatabaseHelper.instance.insertLabel(l);
      }
    }
    notifyListeners();
  }

  Future<void> addLabel(ActivityCategoryLabel label) async {
    label.sortOrder = _labels.length;
    _labels.add(label);
    notifyListeners();
    await DatabaseHelper.instance.insertLabel(label);
    _autoSyncToFirebase();
  }

  Future<void> updateLabel(ActivityCategoryLabel label) async {
    final index = _labels.indexWhere((l) => l.id == label.id);
    if (index != -1) {
      final oldName = _labels[index].name;
      final newName = label.name;
      _labels[index] = label;

      if (oldName != newName) {
        for (int i = 0; i < _activities.length; i++) {
          final act = _activities[i];
          bool changed = false;

          String? updatedSingleName = act.labelName;
          if (act.labelName == oldName) {
            updatedSingleName = newName;
            changed = true;
          }

          List<String> updatedNames = List.from(act.labelNames);
          if (updatedNames.contains(oldName)) {
            final labelIdx = updatedNames.indexOf(oldName);
            updatedNames[labelIdx] = newName;
            changed = true;
          }

          if (changed) {
            final updatedAct = ActivityLog(
              id: act.id,
              title: act.title,
              startTime: act.startTime,
              endTime: act.endTime,
              description: act.description,
              color: act.color,
              labelId: act.labelId,
              labelName: updatedSingleName,
              labelNames: updatedNames,
            );
            _activities[i] = updatedAct;
            await DatabaseHelper.instance.updateActivity(updatedAct);
          }
        }
      }

      notifyListeners();
      await DatabaseHelper.instance.updateLabel(label);
      _autoSyncToFirebase();
    }
  }

  Future<void> reorderLabels(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _labels.removeAt(oldIndex);
    _labels.insert(newIndex, item);

    for (int i = 0; i < _labels.length; i++) {
      _labels[i].sortOrder = i;
    }

    notifyListeners();
    await DatabaseHelper.instance.updateLabelOrders(_labels);
    _autoSyncToFirebase();
  }

  Future<void> deleteLabel(String id) async {
    _labels.removeWhere((l) => l.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteLabel(id);
    await FirebaseService.instance.deleteFirestoreLabel(id);
  }

  // ==================== Backup & Restore ====================

  Future<String> exportBackupJson() async {
    final map = await DatabaseHelper.instance.exportBackupData();
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<int> importBackupJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format');
    }
    final count = await DatabaseHelper.instance.importBackupData(decoded);
    await _initData();
    return count;
  }

  Future<File> exportBackupToFile() async {
    final jsonStr = await exportBackupJson();
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
    final fileName = 'life_tracker_backup_$dateStr.json';

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final publicFile = File('${downloadDir.path}/$fileName');
        await publicFile.writeAsString(jsonStr);
        return publicFile;
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    return await file.writeAsString(jsonStr);
  }

  Future<int> importBackupFromFilePath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }
    final jsonStr = await file.readAsString();
    _isOfficialFileRestoring = true;
    final count = await importBackupJson(jsonStr);
    try {
      if (FirebaseService.instance.isSignedIn) {
        await FirebaseService.instance.syncFullFirestore();
      }
    } finally {
      _isOfficialFileRestoring = false;
    }
    return count;
  }

  // ==================== Cloud Sync API ====================

  Future<int> syncWithCloud() async {
    int syncedCount = 0;
    if (FirebaseService.instance.isSignedIn || AuthService.instance.isSignedIn) {
      syncedCount = await FirebaseService.instance.syncFullFirestore();
    } else if (CloudSyncService.instance.isConfigured) {
      syncedCount = await CloudSyncService.instance.syncFull();
    } else {
      throw Exception('Please sign in to your account first to enable Cloud Sync');
    }
    await fetchCategories();
    await fetchActivities();
    notifyListeners();
    return syncedCount;
  }
}