import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CitizenAvatarService {
  static const String _avatarKey = 'citizen_profile_avatar_base64';

  static Future<String?> getAvatarBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_avatarKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<void> saveAvatarBytes(List<int> bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, base64Encode(bytes));
  }

  static Future<void> clearAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarKey);
  }
}
