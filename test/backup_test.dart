import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/models/activity_log.dart';

void main() {
  test('Backup Serialization & Deserialization Test', () {
    final activity = ActivityLog(
      id: 'test_123',
      title: 'Coding',
      startTime: DateTime(2026, 8, 10, 23, 0),
      endTime: DateTime(2026, 8, 11, 1, 0),
      description: 'Test backup',
    );

    final map = activity.toMap();
    expect(map['id'], 'test_123');
    expect(map['title'], 'Coding');

    final restored = ActivityLog.fromMap(map);
    expect(restored.id, 'test_123');
    expect(restored.title, 'Coding');
    expect(restored.startTime, DateTime(2026, 8, 10, 23, 0));
    expect(restored.endTime, DateTime(2026, 8, 11, 1, 0));
  });
}
