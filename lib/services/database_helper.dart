import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity_log.dart';
import '../models/activity_category.dart';
import '../models/activity_label.dart';

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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureSchemaUpToDate(db);
      },
    );
  }

  static Future<void> _ensureSchemaUpToDate(Database db) async {
    try {
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_names TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS labels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon_emoji TEXT NOT NULL,
          color INTEGER NOT NULL,
          sort_order INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    } catch (_) {}
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
        color INTEGER,
        label_id TEXT,
        label_name TEXT,
        label_names TEXT
      )
    ''');

    // 2. 创建 categories 表
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // 3. 创建 labels 表
    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_emoji TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // 4. 创建 user_settings & users 表
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
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

    // 💡 4. 老用户升级：版本小于 4 时补充创建 user_settings 表
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_settings (
          key TEXT PRIMARY KEY,
          value TEXT
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

    final List<ActivityLog> logs = [];
    for (var json in result) {
      try {
        logs.add(ActivityLog.fromMap(json));
      } catch (_) {
        // Skip corrupted row if any
      }
    }
    return logs;
  }

  Future<List<ActivityLog>> getActivitiesForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day + 1, 0, 0, 0);

    final allActivities = await getAllActivities();

    return allActivities.where((activity) {
      final start = activity.startTime;
      final end = activity.endTime ?? DateTime(start.year, start.month, start.day, start.hour + 1, start.minute, start.second);

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

  // ==================== Category CRUD ====================

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
    try {
      await db.execute('ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0');
    } catch (_) {}
    final result = await db.query('categories', orderBy: 'sort_order ASC, rowid ASC');
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

  Future<void> updateCategoryOrders(List<ActivityCategory> categories) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < categories.length; i++) {
        categories[i].sortOrder = i;
        await txn.update(
          'categories',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [categories[i].id],
        );
      }
    });
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Label CRUD ====================

  Future<int> insertLabel(ActivityCategoryLabel label) async {
    final db = await instance.database;
    return await db.insert(
      'labels',
      label.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityCategoryLabel>> getAllLabels() async {
    final db = await instance.database;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS labels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon_emoji TEXT NOT NULL,
          color INTEGER NOT NULL,
          sort_order INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_id TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_name TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN label_names TEXT');
    } catch (_) {}

    final result = await db.query('labels', orderBy: 'sort_order ASC, rowid ASC');
    return result.map((json) => ActivityCategoryLabel.fromMap(json)).toList();
  }

  Future<int> updateLabel(ActivityCategoryLabel label) async {
    final db = await instance.database;
    return await db.update(
      'labels',
      label.toMap(),
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  Future<void> updateLabelOrders(List<ActivityCategoryLabel> labels) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < labels.length; i++) {
        labels[i].sortOrder = i;
        await txn.update(
          'labels',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [labels[i].id],
        );
      }
    });
  }

  Future<int> deleteLabel(String id) async {
    final db = await instance.database;
    return await db.delete(
      'labels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== User Settings API (💡 规范方法) ====================

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // ==================== Data Backup & Restore API ====================

  Future<Map<String, dynamic>> exportBackupData() async {
    final db = await instance.database;
    final activityResult = await db.query('activity_logs');
    final categoryResult = await db.query('categories');

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'activity_logs': activityResult,
      'categories': categoryResult,
    };
  }

  Future<int> importBackupData(Map<String, dynamic> backupMap) async {
    final db = await instance.database;
    int importedCount = 0;

    await db.transaction((txn) async {
      if (backupMap['categories'] is List) {
        final categoriesList = backupMap['categories'] as List;
        for (var item in categoriesList) {
          if (item is Map<String, dynamic>) {
            await txn.insert(
              'categories',
              item,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      if (backupMap['activity_logs'] is List) {
        final activitiesList = backupMap['activity_logs'] as List;
        for (var item in activitiesList) {
          if (item is Map<String, dynamic>) {
            await txn.insert(
              'activity_logs',
              item,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            importedCount++;
          }
        }
      }
    });

    return importedCount;
  }

  // ==================== User Accounts API ====================

  Future<void> registerUser(String email, String passwordHash) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.insert(
      'users',
      {
        'email': email.toLowerCase().trim(),
        'password_hash': passwordHash,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  /// Clear all local activity logs, categories, and labels upon account sign out
  Future<void> clearLocalUserData() async {
    final db = await database;
    await db.delete('activity_logs');
    await db.delete('categories');
    try {
      await db.delete('labels');
    } catch (_) {}
  }
}