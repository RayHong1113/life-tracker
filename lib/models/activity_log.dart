/// Represents a single time-blocked activity or task log.
class ActivityLog {
  final String id;
  final String title;         // Activity description (e.g., "Studying Flutter", "Work Shift")
  final DateTime startTime;   // Start timestamp
  final DateTime? endTime;    // End timestamp (nullable if the activity is currently ongoing)
  final String description;   // Optional detailed notes

  ActivityLog({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description = '',
  });

  /// Converts the [ActivityLog] instance into a [Map] for SQLite database storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'description': description,
    };
  }

  /// Creates an [ActivityLog] instance from a database [Map].
  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as String,
      title: map['title'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null 
          ? DateTime.parse(map['end_time'] as String) 
          : null,
      description: map['description'] as String? ?? '',
    );
  }
}