import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/services/cloud_sync_service.dart';

void main() {
  test('CloudSyncService initial state test', () {
    final service = CloudSyncService.instance;
    expect(service.isConfigured, isFalse);
    expect(service.autoSyncEnabled, isTrue);
  });
}
