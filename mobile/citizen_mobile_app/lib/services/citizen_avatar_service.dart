import 'package:flutter/foundation.dart';

class CitizenAvatarService {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static String? _cachedAvatarUrl;

  static String? get cachedAvatarUrl => _cachedAvatarUrl;

  static String? avatarUrlFromUser(Map<String, dynamic>? user) {
    if (user == null) {
      return null;
    }

    final rawUrl =
        (user['profile_image_url'] ??
                user['profile_photo_url'] ??
                user['profile_image'] ??
                '')
            .toString()
            .trim();

    if (rawUrl.isEmpty) {
      return null;
    }

    return rawUrl;
  }

  static void syncFromUser(Map<String, dynamic>? user) {
    final nextUrl = avatarUrlFromUser(user);
    if (_cachedAvatarUrl == nextUrl) {
      return;
    }

    _cachedAvatarUrl = nextUrl;
    revision.value++;
  }

  static Future<void> clearAvatar() async {
    _cachedAvatarUrl = null;
    revision.value++;
  }
}
