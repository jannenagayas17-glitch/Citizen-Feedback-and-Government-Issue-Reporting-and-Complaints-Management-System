import 'package:citizen_mobile_app/services/citizen_avatar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await CitizenAvatarService.clearAvatar();
  });

  test('syncs and clears the cached profile image URL', () async {
    CitizenAvatarService.syncFromUser({
      'profile_image_url':
          'http://localhost:8000/api/profile-images/profile_images/12/avatar.png',
    });

    expect(
      CitizenAvatarService.cachedAvatarUrl,
      'http://localhost:8000/api/profile-images/profile_images/12/avatar.png',
    );

    await CitizenAvatarService.clearAvatar();

    expect(CitizenAvatarService.cachedAvatarUrl, isNull);
  });

  test('supports the legacy profile photo URL key when present', () {
    CitizenAvatarService.syncFromUser({
      'profile_photo_url':
          'http://localhost:8000/api/profile-images/profile_images/12/avatar.png',
    });

    expect(
      CitizenAvatarService.cachedAvatarUrl,
      'http://localhost:8000/api/profile-images/profile_images/12/avatar.png',
    );
  });
}
