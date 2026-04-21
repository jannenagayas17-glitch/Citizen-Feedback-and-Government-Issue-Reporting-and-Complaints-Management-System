import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/screens/auth/register_screen.dart';
import 'package:staff_mobile_app/services/auth_service.dart';
import 'package:staff_mobile_app/utils/app_routes.dart';

import '../test_helpers.dart';

class _FakeStaffAuthService extends AuthService {
  bool requestCalled = false;

  @override
  Future<List<dynamic>> getOffices({bool includeInactive = false}) async {
    return const [
      {'name': 'City Engineer\'s Office'},
      {'name': 'City Health Office'},
    ];
  }

  @override
  Future<Map<String, dynamic>> requestGovernmentAccount({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
    required String department,
    required String jobTitle,
  }) async {
    requestCalled = true;
    return {'message': 'Admin request submitted.'};
  }
}

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  Future<void> pumpRegisterScreen(
    WidgetTester tester, {
    required AuthService authService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(authService: authService),
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login Page')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors when admin register is empty', (
    tester,
  ) async {
    await pumpRegisterScreen(tester, authService: _FakeStaffAuthService());

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(find.text('Please select an office.'), findsOneWidget);
    expect(find.text('Please select an admin type.'), findsOneWidget);
    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Mobile number is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Please confirm your password.'), findsOneWidget);
  });

  testWidgets('submits when admin register form is valid', (tester) async {
    final authService = _FakeStaffAuthService();
    await pumpRegisterScreen(tester, authService: authService);

    await tester.tap(find.text('Select office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("City Engineer's Office").last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select admin type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office Head').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Jericson');
    await tester.enterText(find.byType(TextField).at(1), 'Cupan');
    await tester.enterText(find.byType(TextField).at(2), 'jericson@test.com');
    await tester.enterText(find.byType(TextField).at(3), '09170000002');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(authService.requestCalled, isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });
}
