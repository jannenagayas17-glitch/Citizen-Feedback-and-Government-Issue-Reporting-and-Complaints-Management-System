import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/screens/auth/login_screen.dart';
import 'package:staff_mobile_app/services/auth_service.dart';
import 'package:staff_mobile_app/utils/app_routes.dart';
import 'package:staff_mobile_app/utils/app_theme_controller.dart';
import 'package:staff_mobile_app/utils/token_storage.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    configureTestViewport(tester);
    final themeController = AppThemeController();
    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: MaterialApp(
          home: LoginScreen(authService: authService),
          routes: {
            AppRoutes.adminHome: (_) =>
                const Scaffold(body: Text('Admin Home')),
            AppRoutes.frontDeskHome: (_) =>
                const Scaffold(body: Text('Front Desk Home')),
            AppRoutes.superAdminHome: (_) =>
                const Scaffold(body: Text('Super Admin Home')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors when admin login is empty', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('switching to super admin mode does not force a fallback email', (
    tester,
  ) async {
    await TokenStorage.saveLastEmailForRole(
      role: 'admin',
      email: 'admin@test.com',
    );

    await pumpLoginScreen(tester);

    await tester.tap(find.byType(DropdownButtonFormField<LoginMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Super Admin').last);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.keyboardType == TextInputType.emailAddress &&
            widget.controller.text.isEmpty,
      ),
      findsOneWidget,
    );
  });

  testWidgets('routes administrative staff login to the front desk home', (
    tester,
  ) async {
    await pumpLoginScreen(
      tester,
      authService: _FakeAuthService(
        user: const {
          'id': 4,
          'role': 'administrative_staff',
          'email': 'frontdesk@test.com',
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'frontdesk@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'FrontDeskPass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Front Desk Home'), findsOneWidget);
    expect(find.text('Admin Home'), findsNothing);
  });

  testWidgets(
    'routes a super admin email-password login to the super admin home',
    (tester) async {
      await pumpLoginScreen(
        tester,
        authService: _FakeAuthService(
          user: const {
            'id': 1,
            'role': 'super_admin',
            'email': 'owner@test.com',
          },
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'owner@test.com');
      await tester.enterText(
        find.byType(TextField).at(1),
        'CorrectPassword123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Super Admin Home'), findsOneWidget);
    },
  );
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
