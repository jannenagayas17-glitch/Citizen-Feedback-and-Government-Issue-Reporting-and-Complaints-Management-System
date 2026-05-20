import 'package:citizen_mobile_app/models/report_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'normalizeReportList unwraps nested report payloads and removes duplicates',
    () {
      final reports = CitizenReportModel.normalizeReportList([
        {
          'message': 'Report created successfully',
          'report': {
            'id': 12,
            'title': 'Broken road',
            'status': 'New',
            'created_at': '2026-05-11T01:00:00Z',
          },
        },
        {
          'id': 12,
          'title': 'Broken road',
          'status': 'New',
          'created_at': '2026-05-11T01:00:00Z',
        },
        {
          'id': 9,
          'title': 'Water leak',
          'status': 'Resolved',
          'created_at': '2026-05-10T01:00:00Z',
        },
      ]);

      expect(reports, hasLength(2));
      expect(CitizenReportModel.reportIdOf(reports.first), 12);
      expect(CitizenReportModel.reportIdOf(reports.last), 9);
    },
  );

  test('timelineFor reflects the selected report real rejection path', () {
    final timeline = CitizenReportModel.timelineFor({
      'id': 7,
      'status': 'Rejected',
      'created_at': '2026-05-10T08:00:00Z',
      'updated_at': '2026-05-11T12:30:00Z',
      'status_histories': [
        {
          'id': 1,
          'old_status': 'New',
          'new_status': 'In Progress',
          'created_at': '2026-05-10T10:00:00Z',
        },
        {
          'id': 2,
          'old_status': 'In Progress',
          'new_status': 'Rejected',
          'remarks': 'Insufficient evidence.',
          'created_at': '2026-05-11T12:30:00Z',
        },
      ],
    });

    expect(timeline, hasLength(4));
    expect(timeline[0].title, 'Submitted');
    expect(timeline[0].completed, isTrue);
    expect(timeline[1].title, 'In Progress');
    expect(timeline[1].completed, isTrue);
    expect(timeline[2].title, 'Resolved');
    expect(timeline[2].completed, isFalse);
    expect(timeline[3].title, 'Rejected');
    expect(timeline[3].active, isTrue);
  });

  test('adminRemarkOf falls back to a clean empty-state message', () {
    expect(
      CitizenReportModel.adminRemarkOf({
        'id': 3,
        'status': 'Pending',
        'admin_responses': const [],
        'status_histories': const [],
      }),
      'No admin remarks yet.',
    );
  });

  test('privacy helpers reflect anonymous report state', () {
    expect(
      CitizenReportModel.isAnonymousOf({
        'id': 18,
        'is_anonymous': true,
      }),
      isTrue,
    );
    expect(
      CitizenReportModel.privacyLabelOf({
        'id': 18,
        'is_anonymous': true,
      }),
      'Anonymous to admins',
    );
    expect(
      CitizenReportModel.privacyLabelOf({
        'id': 19,
        'is_anonymous': false,
      }),
      'Identity visible to admins',
    );
  });
}
