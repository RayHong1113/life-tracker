import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity_log.dart';

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
      version: 2,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
  }

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

    // 当天的起点 (00:00:00) 和终点 (23:59:59)
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final allActivities = await getAllActivities();

    // 过滤出所有与当天时间段有交集的活动（包含跨天）
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
}