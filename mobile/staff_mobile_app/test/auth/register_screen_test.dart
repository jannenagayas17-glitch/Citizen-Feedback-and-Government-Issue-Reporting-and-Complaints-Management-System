import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/screens/auth/register_screen.dart';
import 'package:staff_mobile_app/services/auth_service.dart';
import 'package:staff_mobile_app/utils/app_routes.dart';

import '../test_helpers.dart';

class _FakeStaffAuthService extends AuthService {
  bool requestCalled = false;
  Map<String, dynamic>? lastRequest;

  @override
  Future<List<dynamic>> getOffices({
    bool includeInactive = false,
    bool refresh = false,
  }) async {
    return const [
      {'name': 'City Engineer\'s Office'},
      {'name': 'City Health Office'},
    ];
  }

  @override
  Future<Map<String, dynamic>> requestGovernmentAccount({
    required String name,
    String? firstName,
    String? lastName,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
    required String department,
    required String jobTitle,
  }) async {
    requestCalled = true;
    lastRequest = {
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'mobile_number': mobileNumber,
      'department': department,
      'job_title': jobTitle,
    };
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
    configureTestViewport(tester);
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
    final dropdowns = find.byWidgetPredicate((widget) => widget is DropdownButton);
    final officeDropdown = dropdowns.at(0);
    final adminTypeDropdown = dropdowns.at(1);

    await tester.ensureVisible(officeDropdown);
    await tester.tap(officeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text("City Engineer's Office").last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(adminTypeDropdown);
    await tester.tap(adminTypeDropdown);
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
    expect(authService.lastRequest?['first_name'], 'Jericson');
    expect(authService.lastRequest?['last_name'], 'Cupan');
    expect(authService.lastRequest?['name'], 'Jericson Cupan');
    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets('accepts +63 mobile numbers and title-cases admin names', (
    tester,
  ) async {
    final authService = _FakeStaffAuthService();
    await pumpRegisterScreen(tester, authService: authService);
    final dropdowns = find.byWidgetPredicate((widget) => widget is DropdownButton);

    await tester.ensureVisible(dropdowns.at(0));
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text("City Engineer's Office").last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(dropdowns.at(1));
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office Head').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'maria clara');
    await tester.enterText(find.byType(TextField).at(1), 'santos-javier');
    await tester.enterText(find.byType(TextField).at(2), 'maria.staff@test.com');
    await tester.enterText(find.byType(TextField).at(3), '+639123456789');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(authService.requestCalled, isTrue);
    expect(authService.lastRequest?['first_name'], 'Maria Clara');
    expect(authService.lastRequest?['last_name'], 'Santos-Javier');
    expect(authService.lastRequest?['name'], 'Maria Clara Santos-Javier');
    expect(authService.lastRequest?['mobile_number'], '+639123456789');
    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets('blocks invalid Philippine mobile prefixes for admin registration', (
    tester,
  ) async {
    final authService = _FakeStaffAuthService();
    await pumpRegisterScreen(tester, authService: authService);
    final dropdowns = find.byWidgetPredicate((widget) => widget is DropdownButton);

    await tester.ensureVisible(dropdowns.at(0));
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text("City Engineer's Office").last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(dropdowns.at(1));
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office Head').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'De Leon');
    await tester.enterText(find.byType(TextField).at(2), 'ana.staff@test.com');
    await tester.enterText(find.byType(TextField).at(3), '0231231233');
    await tester.enterText(find.byType(TextField).at(4), 'password123');
    await tester.enterText(find.byType(TextField).at(5), 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(authService.requestCalled, isFalse);
    expect(
      find.text(
        'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.',
      ),
      findsOneWidget,
    );
  });
}
