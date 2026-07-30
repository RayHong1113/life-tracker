import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity_log.dart';

/// Singleton helper class to manage SQLite database operations.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Returns the existing database connection or initializes a new one.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('life_tracker.db');
    return _database!;
  }

  /// Initializes the SQLite database file in the default storage directory.
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Creates the database tables upon initial setup.
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        description TEXT
      )
    ''');
  }

  // ==========================================
  // CRUD Operations (Create, Read, Update, Delete)
  // ==========================================

  /// Inserts a new [ActivityLog] into the database.
  Future<int> insertActivity(ActivityLog activity) async {
    final db = await instance.database;
    return await db.insert('activity_logs', activity.toMap());
  }

  /// Fetches all activity logs, ordered by start time descending (newest first).
  Future<List<ActivityLog>> getAllActivities() async {
    final db = await instance.database;
    final result = await db.query('activity_logs', orderBy: 'start_time DESC');

    return result.map((json) => ActivityLog.fromMap(json)).toList();
  }

  /// Updates an existing [ActivityLog] (e.g., setting the end_time when an activity finishes).
  Future<int> updateActivity(ActivityLog activity) async {
    final db = await instance.database;
    return await db.update(
      'activity_logs',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  /// Deletes an activity log by its ID.
  Future<int> deleteActivity(String id) async {
    final db = await instance.database;
    return await db.delete(
      'activity_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}