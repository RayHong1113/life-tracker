import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log.dart';
import 'database_helper.dart';

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();

  SupabaseClient? _client;
  bool _isInitialized = false;
  bool _autoSyncEnabled = true;

  CloudSyncService._init();

  bool get isConfigured => _client != null && _isInitialized;
  bool get autoSyncEnabled => _autoSyncEnabled;

  Future<void> init() async {
    try {
      final url = await DatabaseHelper.instance.getSetting('cloud_url');
      final key = await DatabaseHelper.instance.getSetting('cloud_key');
      final autoSyncStr =
          await DatabaseHelper.instance.getSetting('cloud_auto_sync');
      _autoSyncEnabled = autoSyncStr != 'false';

      if (url != null && key != null && url.isNotEmpty && key.isNotEmpty) {
        await configure(url, key);
      }
    } catch (e) {
      debugPrint('CloudSyncService init error: $e');
    }
  }

  Future<bool> configure(String url, String anonKey) async {
    try {
      if (url.trim().isEmpty || anonKey.trim().isEmpty) return false;

      await DatabaseHelper.instance.saveSetting('cloud_url', url.trim());
      await DatabaseHelper.instance.saveSetting('cloud_key', anonKey.trim());

      try {
        Supabase.instance.client;
        _client = Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: url.trim(),
          anonKey: anonKey.trim(),
        );
        _client = Supabase.instance.client;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Configure Supabase error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> connectWithGoogleToken({
    String? idToken,
    String? accessToken,
    required String userEmail,
  }) async {
    try {
      if (_client != null && idToken != null && accessToken != null) {
        await _client?.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase Google OAuth Connect Error: $e');
    }
  }

  Future<void> setAutoSync(bool enabled) async {
    _autoSyncEnabled = enabled;
    await DatabaseHelper.instance
        .saveSetting('cloud_auto_sync', enabled ? 'true' : 'false');
  }

  /// Sync single activity creation or edit to Cloud
  Future<void> syncSingleActivity(ActivityLog activity) async {
    if (!isConfigured || !_autoSyncEnabled) return;
    try {
      final map = activity.toMap();
      await _client?.from('activity_logs').upsert(map);
    } catch (e) {
      debugPrint('Cloud sync activity error: $e');
    }
  }

  /// Sync single activity deletion to Cloud
  Future<void> deleteSingleActivity(String id) async {
    if (!isConfigured || !_autoSyncEnabled) return;
    try {
      await _client?.from('activity_logs').delete().eq('id', id);
    } catch (e) {
      debugPrint('Cloud delete activity error: $e');
    }
  }

  /// Full bidirectional synchronization: Push local to Cloud and Pull Cloud to local
  Future<int> syncFull() async {
    if (!isConfigured) {
      throw Exception('Cloud database is not configured');
    }

    int syncedCount = 0;

    try {
      // 1. Push local SQLite records to Cloud
      final backupData = await DatabaseHelper.instance.exportBackupData();
      final localActivities =
          backupData['activity_logs'] as List<Map<String, dynamic>>? ?? [];
      final localCategories =
          backupData['categories'] as List<Map<String, dynamic>>? ?? [];

      if (localCategories.isNotEmpty) {
        await _client?.from('categories').upsert(localCategories);
      }
      if (localActivities.isNotEmpty) {
        await _client?.from('activity_logs').upsert(localActivities);
      }

      // 2. Pull Cloud records and merge into local SQLite DB
      final cloudCategories = await _client?.from('categories').select();
      final cloudActivities = await _client?.from('activity_logs').select();

      final Map<String, dynamic> cloudBackupData = {
        'categories': cloudCategories ?? [],
        'activity_logs': cloudActivities ?? [],
      };

      syncedCount =
          await DatabaseHelper.instance.importBackupData(cloudBackupData);
    } catch (e) {
      debugPrint('Full cloud sync error: $e');
      rethrow;
    }

    return syncedCount;
  }
}
