import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/services/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FirebaseService initialization test', () {
    final service = FirebaseService.instance;
    expect(service.isSignedIn, isFalse);
    expect(service.currentUser, isNull);
  });
}
