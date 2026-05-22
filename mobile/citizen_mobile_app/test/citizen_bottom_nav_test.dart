import 'package:citizen_mobile_app/widgets/citizen_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Updates as the third navigation label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CitizenBottomNav(
            currentIndex: 3,
            onHomeTap: () {},
            onReportsTap: () {},
            onUpdatesTap: () {},
            onProfileTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Alerts'), findsNothing);
  });
}
