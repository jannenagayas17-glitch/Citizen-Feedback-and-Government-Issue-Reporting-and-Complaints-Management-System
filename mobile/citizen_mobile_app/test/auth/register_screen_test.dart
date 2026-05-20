import 'dart:async';

import 'package:citizen_mobile_app/screens/auth/login_screen.dart';
import 'package:citizen_mobile_app/screens/auth/register_screen.dart';
import 'package:citizen_mobile_app/services/auth_service.dart';
import 'package:citizen_mobile_app/utils/app_routes.dart';
import 'package:citizen_mobile_app/utils/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

class _FakeCitizenAuthService extends AuthService {
  int registerCallCount = 0;
  String? capturedFirstName;
  String? capturedLastName;
  String? capturedMobileNumber;
  Completer<Map<String, dynamic>>? responseCompleter;
  String? errorMessage;

  @override
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    registerCallCount += 1;
    capturedFirstName = firstName;
    capturedLastName = lastName;
    capturedMobileNumber = mobileNumber;

    if (errorMessage != null) {
      throw Exception(errorMessage);
    }

    if (responseCompleter != null) {
      return responseCompleter!.future;
    }

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
          routes: {AppRoutes.login: (_) => const LoginScreen()},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> acceptPolicies(WidgetTester tester) async {
    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
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
    expect(
      find.text(
        'You must agree to the Terms & Conditions and Privacy Policy to continue.',
      ),
      findsOneWidget,
    );
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
      find.text(
        'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.',
      ),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('requires terms acceptance before registration', (tester) async {
    final authService = _FakeCitizenAuthService();
    await pumpRegisterScreen(tester, authService: authService);

    await tester.enterText(find.byType(TextField).at(0), 'Maria');
    await tester.enterText(find.byType(TextField).at(1), 'Santos');
    await tester.enterText(find.byType(TextField).at(2), 'maria@test.com');
    await tester.enterText(find.byType(TextField).at(3), '09170000001');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(authService.registerCallCount, 0);
    expect(
      find.text(
        'You must agree to the Terms & Conditions and Privacy Policy to continue.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('register success goes to login with success notification', (
    tester,
  ) async {
    final authService = _FakeCitizenAuthService();
    await pumpRegisterScreen(tester, authService: authService);

    await tester.enterText(find.byType(TextField).at(0), 'Maria Clara');
    await tester.enterText(find.byType(TextField).at(1), 'Dela Cruz');
    await tester.enterText(find.byType(TextField).at(2), 'clark@test.com');
    await tester.enterText(find.byType(TextField).at(3), '09170000001');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');
    await acceptPolicies(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(authService.registerCallCount, 1);
    expect(authService.capturedFirstName, 'Maria Clara');
    expect(authService.capturedLastName, 'Dela Cruz');
    expect(authService.capturedMobileNumber, '+639170000001');
    expect(
      find.text(
        'Registration successful. Please log in with your new account.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);

    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.controller?.text, 'clark@test.com');
  });

  testWidgets('failed registration clears any stale local auth session', (
    tester,
  ) async {
    resetMockPreferences({'auth_token': 'stale-token', 'user_role': 'citizen'});

    final authService = _FakeCitizenAuthService()..errorMessage = 'Email taken';
    await pumpRegisterScreen(tester, authService: authService);

    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'Santos-Javier');
    await tester.enterText(find.byType(TextField).at(2), 'ana@test.com');
    await tester.enterText(find.byType(TextField).at(3), '9170000001');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');
    await acceptPolicies(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(authService.registerCallCount, 1);
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('user_role'), isNull);
    expect(find.text('Citizen Home'), findsNothing);
    expect(find.text('Email taken'), findsOneWidget);
  });

  testWidgets(
    'prevents duplicate submissions while registration is in progress',
    (tester) async {
      final authService = _FakeCitizenAuthService()
        ..responseCompleter = Completer<Map<String, dynamic>>();
      await pumpRegisterScreen(tester, authService: authService);

      await tester.enterText(find.byType(TextField).at(0), 'Liza');
      await tester.enterText(find.byType(TextField).at(1), 'De Leon');
      await tester.enterText(find.byType(TextField).at(2), 'liza@test.com');
      await tester.enterText(find.byType(TextField).at(3), '9171234567');
      await tester.enterText(find.byType(TextField).at(4), 'password123');
      await tester.enterText(find.byType(TextField).at(5), 'password123');
      await acceptPolicies(tester);

      final registerButton = find.widgetWithText(ElevatedButton, 'Register');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pump();

      final buttonWidget = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(authService.registerCallCount, 1);
      expect(buttonWidget.onPressed, isNull);

      authService.responseCompleter!.complete({
        'token': 'fake-token',
        'user': {'role': 'citizen'},
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    },
  );
}
