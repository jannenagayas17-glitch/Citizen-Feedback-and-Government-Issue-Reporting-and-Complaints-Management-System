import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staff_mobile_app/screens/auth/login_screen.dart';
import 'test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  testWidgets('staff login screen renders', (WidgetTester tester) async {
    configureTestViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('City Admin Portal'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
