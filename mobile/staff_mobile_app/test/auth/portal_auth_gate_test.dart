import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/services/auth_service.dart';
import 'package:staff_mobile_app/services/portal_auth_gate.dart';
import 'package:staff_mobile_app/utils/token_storage.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  test('returns login when no stored token exists', () async {
    final gate = PortalAuthGate(authService: _FakeAuthService(user: null));

    final result = await gate.resolve();

    expect(result.shouldOpenLogin, isTrue);
    expect(result.shouldClearStoredSession, isTrue);
  });

  test('returns super admin home when token is valid', () async {
    await TokenStorage.saveToken('valid-token');

    final gate = PortalAuthGate(
      authService: _FakeAuthService(
        user: {'id': 1, 'role': 'super_admin', 'email': 'super@test.com'},
      ),
    );

    final result = await gate.resolve();

    expect(result.shouldOpenLogin, isFalse);
    expect(result.normalizedRole, 'super_admin');
    expect(result.user?['email'], 'super@test.com');
  });

  test('returns administrative staff home when token is valid', () async {
    await TokenStorage.saveToken('front-desk-token');

    final gate = PortalAuthGate(
      authService: _FakeAuthService(
        user: {
          'id': 8,
          'role': 'administrative_staff',
          'email': 'desk@test.com',
        },
      ),
    );

    final result = await gate.resolve();

    expect(result.shouldOpenLogin, isFalse);
    expect(result.shouldClearStoredSession, isFalse);
    expect(result.normalizedRole, 'administrative_staff');
    expect(result.user?['email'], 'desk@test.com');
  });

  test('clears non-admin sessions back to login', () async {
    await TokenStorage.saveToken('citizen-token');

    final gate = PortalAuthGate(
      authService: _FakeAuthService(
        user: {'id': 44, 'role': 'citizen', 'email': 'citizen@test.com'},
      ),
    );

    final result = await gate.resolve();

    expect(result.shouldOpenLogin, isTrue);
    expect(result.shouldClearStoredSession, isTrue);
  });

  test('returns login notice when session lookup fails', () async {
    await TokenStorage.saveToken('expired-token');

    final gate = PortalAuthGate(
      authService: _FakeAuthService(
        user: null,
        error: Exception('Session expired. Please log in again.'),
      ),
    );

    final result = await gate.resolve();

    expect(result.shouldOpenLogin, isTrue);
    expect(result.shouldClearStoredSession, isTrue);
    expect(result.message, 'Session expired. Please log in again.');
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.user, this.error});

  final Map<String, dynamic>? user;
  final Exception? error;

  @override
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (error != null) {
      throw error!;
    }

    if (user == null) {
      throw Exception('Missing fake user.');
    }

    return user!;
  }
}
