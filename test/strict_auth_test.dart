import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthService strict hashing function unit test', () async {
    final auth = AuthService.instance;
    expect(auth.isSignedIn, isFalse);

    // Verify empty or invalid password throwing exception
    expect(
      () async => await auth.signIn('', ''),
      throwsA(isA<Exception>()),
    );

    expect(
      () async => await auth.signUp('invalid_email', '123'),
      throwsA(isA<Exception>()),
    );
  });
}
