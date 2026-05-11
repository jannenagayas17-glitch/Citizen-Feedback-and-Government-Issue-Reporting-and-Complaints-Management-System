import 'package:citizen_mobile_app/screens/auth/register_screen.dart';
import 'package:citizen_mobile_app/services/auth_service.dart';
import 'package:citizen_mobile_app/utils/app_routes.dart';
import 'package:citizen_mobile_app/utils/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

class _FakeCitizenAuthService extends AuthService {
  bool registerCalled = false;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    registerCalled = true;
    return {
      'token': 'fake-token',
      'user': {'role': 'citizen'},
    };
  }
}

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  Future<void> pumpRegisterScreen(
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
          home: RegisterScreen(authService: authService),
          routes: {
            AppRoutes.citizenHome: (_) =>
                const Scaffold(body: Text('Citizen Home')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors when register is empty', (tester) async {
    await pumpRegisterScreen(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Mobile number is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Please confirm your password.'), findsOneWidget);
  });

  testWidgets('shows validation errors for invalid phone and mismatch', (
    tester,
  ) async {
    await pumpRegisterScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Clark');
    await tester.enterText(find.byType(TextField).at(1), 'James');
    await tester.enterText(find.byType(TextField).at(2), 'invalid-email');
    await tester.enterText(find.byType(TextField).at(3), '0917');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password321');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Mobile number must be exactly 11 digits.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('submits when citizen register form is valid', (tester) async {
    final authService = _FakeCitizenAuthService();
    await pumpRegisterScreen(tester, authService: authService);

    await tester.enterText(find.byType(TextField).at(0), 'Clark');
    await tester.enterText(find.byType(TextField).at(1), 'James');
    await tester.enterText(find.byType(TextField).at(2), 'clark@test.com');
    await tester.enterText(find.byType(TextField).at(3), '09170000001');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(authService.registerCalled, isTrue);
    expect(find.text('Citizen Home'), findsOneWidget);
  });
}
