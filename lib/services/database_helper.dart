import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity_log.dart';
import '../models/activity_category.dart'; // 💡 导入分类 Model

/// Singleton helper class to manage SQLite database operations.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('life_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // 💡 升到 Version 3
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. 创建 activity_logs 表
    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        description TEXT,
        color INTEGER
      )
    ''');

    // 💡 2. 新增 categories 表
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon_code INTEGER NOT NULL,
          color INTEGER NOT NULL
        )
      ''');
    }
  }

  // ==================== Activity Log CRUD ====================

  Future<int> insertActivity(ActivityLog activity) async {
    final db = await instance.database;
    return await db.insert('activity_logs', activity.toMap());
  }

  Future<List<ActivityLog>> getAllActivities() async {
    final db = await instance.database;
    final result = await db.query('activity_logs', orderBy: 'start_time DESC');

    return result.map((json) => ActivityLog.fromMap(json)).toList();
  }

  Future<List<ActivityLog>> getActivitiesForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final allActivities = await getAllActivities();

    return allActivities.where((activity) {
      final start = activity.startTime;
      final end = activity.endTime ?? start.add(const Duration(hours: 1));

      return start.isBefore(dayEnd) && end.isAfter(dayStart);
    }).toList();
  }

  Future<int> updateActivity(ActivityLog activity) async {
    final db = await instance.database;
    return await db.update(
      'activity_logs',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<int> deleteActivity(String id) async {
    final db = await instance.database;
    return await db.delete(
      'activity_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Category CRUD (💡 新增) ====================

  Future<int> insertCategory(ActivityCategory category) async {
    final db = await instance.database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityCategory>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => ActivityCategory.fromMap(json)).toList();
  }

  Future<int> updateCategory(ActivityCategory category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}