import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/services/auth_service.dart';

void main() {
  test('AuthService initial state test', () {
    final service = AuthService.instance;
    expect(service.isSignedIn, isFalse);
    expect(service.currentUser, isNull);
  });
}
