import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/screens/auth/login_screen.dart';
import 'package:staff_mobile_app/utils/token_storage.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    configureTestViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
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

  testWidgets('switching to super admin mode fills the configured email', (
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
            widget.controller.text == 'superadmin@gmail.com',
      ),
      findsOneWidget,
    );
  });
}
