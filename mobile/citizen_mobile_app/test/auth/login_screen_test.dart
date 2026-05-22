import 'package:citizen_mobile_app/screens/auth/login_screen.dart';
import 'package:citizen_mobile_app/services/auth_service.dart';
import 'package:citizen_mobile_app/services/citizen_avatar_service.dart';
import 'package:citizen_mobile_app/utils/app_routes.dart';
import 'package:citizen_mobile_app/utils/app_theme_controller.dart';
import 'package:citizen_mobile_app/utils/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() async {
    resetMockPreferences();
    await CitizenAvatarService.clearAvatar();
  });

  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    configureTestViewport(tester);
    final themeController = AppThemeController();
    await themeController.load();
    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: MaterialApp(
          home: LoginScreen(authService: authService),
          routes: {
            AppRoutes.citizenHome: (_) =>
                const Scaffold(body: Text('Citizen Home')),
            AppRoutes.frontDeskHome: (_) =>
                const Scaffold(body: Text('Administrative Staff Home')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows required validation errors when login is empty', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('loads the remembered citizen email', (tester) async {
    await TokenStorage.saveLastEmailForRole(
      role: 'citizen',
      email: 'saved@citizen.test',
    );

    await pumpLoginScreen(tester);

    expect(find.text('saved@citizen.test'), findsOneWidget);
  });

  testWidgets(
    'routes an administrative staff account to the assisted workspace',
    (tester) async {
      await pumpLoginScreen(
        tester,
        authService: _FakeAuthService(
          user: const {
            'id': 12,
            'role': 'administrative_staff',
            'email': 'adminstaff@test.com',
          },
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        'adminstaff@test.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'FrontDeskPass123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Administrative Staff Home'), findsOneWidget);
    },
  );

  testWidgets('syncs the cached avatar URL from the login response', (
    tester,
  ) async {
    await pumpLoginScreen(
      tester,
      authService: _FakeAuthService(
        user: const {
          'id': 18,
          'role': 'citizen',
          'email': 'citizen@test.com',
          'profile_image_url':
              'http://localhost:8000/api/profile-images/profile_images/18/avatar.png',
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'citizen@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'CitizenPass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      CitizenAvatarService.cachedAvatarUrl,
      'http://localhost:8000/api/profile-images/profile_images/18/avatar.png',
    );
  });
}

class _FakeAuthService extends AuthService {
  // ignore: unused_element_parameter
  _FakeAuthService({required this.user, this.error});

  final Map<String, dynamic>? user;
  final Exception? error;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (error != null) {
      throw error!;
    }

    if (user == null) {
      throw Exception('Missing fake user.');
    }

    return {'token': 'fake-token', 'user': user!};
  }
}
