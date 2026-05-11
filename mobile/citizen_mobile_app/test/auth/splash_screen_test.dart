import 'package:citizen_mobile_app/screens/splash/splash_screen.dart';
import 'package:citizen_mobile_app/services/auth_service.dart';
import 'package:citizen_mobile_app/utils/app_routes.dart';
import 'package:citizen_mobile_app/utils/app_theme_controller.dart';
import 'package:citizen_mobile_app/utils/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(this._handler);

  final Future<Map<String, dynamic>> Function() _handler;

  @override
  Future<Map<String, dynamic>> getCurrentUser() {
    return _handler();
  }
}

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  Future<void> pumpSplashScreen(
    WidgetTester tester, {
    required AuthService authService,
  }) async {
    configureTestViewport(tester);
    final themeController = AppThemeController();
    await themeController.load();

    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: MaterialApp(
          home: SplashScreen(
            authService: authService,
            bootstrapDelay: Duration.zero,
          ),
          routes: {
            AppRoutes.login: (_) =>
                const Scaffold(body: Center(child: Text('LOGIN PAGE'))),
            AppRoutes.citizenHome: (_) =>
                const Scaffold(body: Center(child: Text('CITIZEN HOME'))),
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('opens the login page when no token is stored', (tester) async {
    await pumpSplashScreen(
      tester,
      authService: _FakeAuthService(
        () async => throw Exception('Should not fetch a user without a token.'),
      ),
    );

    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('opens the citizen home when the backend confirms the session', (
    tester,
  ) async {
    resetMockPreferences({'auth_token': 'valid-token', 'user_role': 'citizen'});

    await pumpSplashScreen(
      tester,
      authService: _FakeAuthService(
        () async => {
          'id': 10,
          'name': 'Citizen User',
          'email': 'citizen@example.com',
          'role': 'citizen',
        },
      ),
    );

    expect(find.text('CITIZEN HOME'), findsOneWidget);
  });

  testWidgets(
    'clears stale session data and returns to login on invalid user',
    (tester) async {
      resetMockPreferences({
        'auth_token': 'stale-token',
        'user_role': 'citizen',
      });

      await pumpSplashScreen(
        tester,
        authService: _FakeAuthService(
          () async => {
            'id': 44,
            'name': 'Admin User',
            'email': 'admin@example.com',
            'role': 'admin',
          },
        ),
      );

      expect(find.text('LOGIN PAGE'), findsOneWidget);
      expect(await TokenStorage.getToken(), isNull);
      expect(await TokenStorage.getRole(), isNull);
    },
  );
}
