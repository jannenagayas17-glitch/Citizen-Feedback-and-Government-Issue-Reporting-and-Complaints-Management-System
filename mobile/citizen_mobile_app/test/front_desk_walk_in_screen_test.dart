import 'package:citizen_mobile_app/screens/front_desk/front_desk_walk_in_screen.dart';
import 'package:citizen_mobile_app/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'test_helpers.dart';

class _FakeReportService extends ReportService {
  Map<String, dynamic>? submission;

  @override
  Future<List<dynamic>> getOffices() async {
    return const [
      {'id': 10, 'name': "City Engineer's Office"},
    ];
  }

  @override
  Future<List<dynamic>> getCategories() async {
    return const [
      {'id': 55, 'name': 'Road Repairs'},
    ];
  }

  @override
  Future<Map<String, dynamic>> createWalkInReport({
    int? categoryId,
    String? categoryName,
    required int officeId,
    required String title,
    required String description,
    required String location,
    required String barangay,
    required String walkInFullName,
    required String walkInContactNumber,
    required String walkInAddress,
    String? walkInEmail,
    String? priority,
    bool isSeniorCitizen = false,
    bool isPwd = false,
    DateTime? expectedReturnAt,
    List<XFile> mediaFiles = const <XFile>[],
  }) async {
    submission = {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'officeId': officeId,
      'title': title,
      'description': description,
      'location': location,
      'barangay': barangay,
      'walkInFullName': walkInFullName,
      'walkInContactNumber': walkInContactNumber,
      'walkInAddress': walkInAddress,
      'walkInEmail': walkInEmail,
      'priority': priority,
      'isSeniorCitizen': isSeniorCitizen,
      'isPwd': isPwd,
      'expectedReturnAt': expectedReturnAt,
      'mediaCount': mediaFiles.length,
    };

    return {
      'report': {
        'id': 101,
        'title': title,
        'barangay': barangay,
        'location': location,
        'complainant_name': walkInFullName,
        'complainant_is_senior_citizen': isSeniorCitizen,
        'complainant_is_pwd': isPwd,
      },
    };
  }
}

void main() {
  setupWidgetTestEnvironment();

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeReportService reportService,
  ) async {
    configureTestViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FrontDeskWalkInScreen(reportService: reportService),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'submits a walk-in complaint with barangay picker selection and exclusive citizen type',
    (tester) async {
      final reportService = _FakeReportService();

      await pumpScreen(tester, reportService);

      await tester.enterText(find.byType(TextField).at(0), 'Maria Santos');
      await tester.enterText(find.byType(TextField).at(1), '09171234567');
      await tester.enterText(
        find.byType(TextField).at(2),
        'maria.santos@example.com',
      );
      await tester.enterText(
        find.byType(TextField).at(3),
        'Purok 3, Tacloban City',
      );

      await tester.tap(find.text('Senior Citizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PWD'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextField).at(4));
      await tester.tap(find.byType(TextField).at(4));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Barangay 13');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Barangay 13'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>).at(0));
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text("City Engineer's Office").last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>).at(1));
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Road Repairs').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(5),
        'Near Tacloban Public Market',
      );
      await tester.enterText(
        find.byType(TextField).at(6),
        'Flooded roadside drainage',
      );
      await tester.enterText(
        find.byType(TextField).at(7),
        'Floodwater is blocking the roadside drainage and needs assistance.',
      );

      await tester.tap(find.text('Submit Assisted Complaint'));
      await tester.pumpAndSettle();

      expect(reportService.submission, isNotNull);
      expect(reportService.submission!['barangay'], 'Barangay 13');
      expect(
        reportService.submission!['location'],
        'Near Tacloban Public Market',
      );
      expect(reportService.submission!['isSeniorCitizen'], isFalse);
      expect(reportService.submission!['isPwd'], isTrue);
      expect(reportService.submission!['officeId'], 10);
      expect(reportService.submission!['categoryId'], 55);
    },
  );
}
