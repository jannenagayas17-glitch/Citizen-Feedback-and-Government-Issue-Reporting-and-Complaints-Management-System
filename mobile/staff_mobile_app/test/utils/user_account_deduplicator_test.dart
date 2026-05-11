import 'package:flutter_test/flutter_test.dart';

import 'package:staff_mobile_app/utils/user_account_deduplicator.dart';

void main() {
  test(
    'deduplicateManagedUsers collapses duplicate emails case-insensitively',
    () {
      final users = [
        {
          'id': 1,
          'name': 'Archived Citizen',
          'email': 'Citizen@Test.com',
          'role': 'citizen',
          'is_active': false,
          'deleted_at': '2026-05-01T10:00:00.000000Z',
          'updated_at': '2026-05-01T10:00:00.000000Z',
        },
        {
          'id': 2,
          'name': 'Active Citizen',
          'email': ' citizen@test.com ',
          'role': 'citizen',
          'is_active': true,
          'deleted_at': null,
          'updated_at': '2026-05-02T10:00:00.000000Z',
        },
        {
          'id': 3,
          'name': 'Another User',
          'email': 'another@test.com',
          'role': 'admin',
          'is_active': true,
        },
      ];

      final deduped = deduplicateManagedUsers(users);

      expect(deduped, hasLength(2));
      expect(
        deduped.where(
          (user) => normalizedManagedUserEmail(user) == 'citizen@test.com',
        ),
        hasLength(1),
      );
      expect(
        deduped.firstWhere(
          (user) => normalizedManagedUserEmail(user) == 'citizen@test.com',
        )['id'],
        2,
      );
    },
  );

  test(
    'managedUserDeduplicationKey falls back to the user id when email is blank',
    () {
      final user = {'id': 42, 'email': '   '};

      expect(managedUserDeduplicationKey(user), 'id:42');
    },
  );

  test(
    'deduplicateManagedUsers keeps distinct same-name accounts when emails differ',
    () {
      final users = [
        {
          'id': 172,
          'name': 'Aileen Dela Cruz',
          'email': 'demo.citizen.0018@example.com',
          'role': 'citizen',
          'mobile_number': '09270000018',
        },
        {
          'id': 222,
          'name': 'Aileen Dela Cruz',
          'email': 'demo.citizen.0068@example.com',
          'role': 'citizen',
          'mobile_number': '09270000068',
        },
      ];

      final deduped = deduplicateManagedUsers(users);

      expect(deduped, hasLength(2));
      expect(deduped.map((user) => normalizedManagedUserEmail(user)).toSet(), {
        'demo.citizen.0018@example.com',
        'demo.citizen.0068@example.com',
      });
    },
  );

  test(
    'duplicateManagedUserEmailGroups reports only normalized email clashes',
    () {
      final groups = duplicateManagedUserEmailGroups([
        {'id': 10, 'name': 'Legacy Citizen', 'email': ' Citizen@Test.com '},
        {'id': 11, 'name': 'Current Citizen', 'email': 'citizen@test.com'},
        {'id': 12, 'name': 'Different Citizen', 'email': 'other@test.com'},
      ]);

      expect(groups.keys, {'citizen@test.com'});
      expect(groups['citizen@test.com'], hasLength(2));
    },
  );
}
