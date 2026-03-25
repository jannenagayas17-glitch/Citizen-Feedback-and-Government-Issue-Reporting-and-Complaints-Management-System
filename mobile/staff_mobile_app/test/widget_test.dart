import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staff_mobile_app/screens/auth/login_screen.dart';

void main() {
  testWidgets('staff login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('City Engineering Portal'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
