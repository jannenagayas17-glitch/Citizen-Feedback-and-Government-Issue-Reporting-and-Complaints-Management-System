import 'package:citizen_mobile_app/screens/auth/login_screen.dart';
import 'package:citizen_mobile_app/utils/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
