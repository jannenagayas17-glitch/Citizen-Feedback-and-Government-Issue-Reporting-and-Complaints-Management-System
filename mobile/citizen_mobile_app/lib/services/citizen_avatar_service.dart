import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenAvatarService {
  static const String _avatarKey = 'citizen_profile_avatar_base64';
  static const int _maxAvatarBase64Length = 900000;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static String? _cachedAvatarBase64;

  static String? get cachedAvatarBase64 => _cachedAvatarBase64;

  static Future<String?> getAvatarBase64() async {
    if (_cachedAvatarBase64 != null) {
      return _cachedAvatarBase64;
    }

    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_avatarKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length > _maxAvatarBase64Length) {
      await prefs.remove(_avatarKey);
      return null;
    }
    _cachedAvatarBase64 = value;
    return value;
  }

  static Future<void> saveAvatarBytes(List<int> bytes) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedAvatarBase64 = base64Encode(bytes);
    if (_cachedAvatarBase64!.length > _maxAvatarBase64Length) {
      throw Exception('Profile photo is too large. Please choose another one.');
    }
    await prefs.setString(_avatarKey, _cachedAvatarBase64!);
    revision.value++;
  }

  static Future<void> clearAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedAvatarBase64 = null;
    await prefs.remove(_avatarKey);
    revision.value++;
  }
}
