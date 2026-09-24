import '../../../models/activity_log.dart';

/// Data class representing an activity positioned on the multi-column timeline grid.
class PositionedActivity {
  final ActivityLog activity;
  int column = 0;
  int totalColumns = 1;

  PositionedActivity(this.activity);
}
