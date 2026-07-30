import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../services/database_helper.dart';

/// ViewModel/Provider class responsible for managing the state of activity logs.
class ActivityProvider with ChangeNotifier {
  List<ActivityLog> _activities = [];
  bool _isLoading = false;

  /// Public getters to access private state variables.
  List<ActivityLog> get activities => _activities;
  bool get isLoading => _isLoading;

  /// Fetches all activity logs from the SQLite database and updates the state.
  Future<void> fetchActivities() async {
    _isLoading = true;
    notifyListeners();

    _activities = await DatabaseHelper.instance.getAllActivities();

    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new activity log to the database and refreshes the list.
  Future<void> addActivity(ActivityLog activity) async {
    await DatabaseHelper.instance.insertActivity(activity);
    await fetchActivities();
  }

  /// Updates an existing activity log (e.g., setting end_time) and refreshes the list.
  Future<void> updateActivity(ActivityLog activity) async {
    await DatabaseHelper.instance.updateActivity(activity);
    await fetchActivities();
  }

  /// Deletes an activity log by ID and refreshes the list.
  Future<void> deleteActivity(String id) async {
    await DatabaseHelper.instance.deleteActivity(id);
    await fetchActivities();
  }
}