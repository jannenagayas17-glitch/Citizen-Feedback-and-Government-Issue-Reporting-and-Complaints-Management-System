import 'package:shared_preferences/shared_preferences.dart';

import 'web_auth_storage.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _lastCitizenEmailKey = 'last_citizen_email';
  static const String _lastAdminEmailKey = 'last_admin_email';
  static const String _lastAdministrativeStaffEmailKey =
      'last_administrative_staff_email';
  static const String _lastFrontDeskEmailKey = 'last_front_desk_email';
  static const String _lastSuperAdminEmailKey = 'last_super_admin_email';

  static const List<String> _authStorageKeys = <String>[_tokenKey, _roleKey];

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _normalizeRole(role));
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    return role == null ? null : _normalizeRole(role);
  }

  static Future<void> saveLastEmailForRole({
    required String role,
    required String email,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKeyForRole(normalizedRole), normalizedEmail);
  }

  static Future<String?> getLastEmailForRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = _normalizeRole(role);

    if (normalizedRole == 'administrative_staff') {
      return prefs.getString(_lastAdministrativeStaffEmailKey) ??
          prefs.getString(_lastFrontDeskEmailKey);
    }

    return prefs.getString(_emailKeyForRole(normalizedRole));
  }

  static String _emailKeyForRole(String role) {
    switch (_normalizeRole(role)) {
      case 'admin':
        return _lastAdminEmailKey;
      case 'administrative_staff':
        return _lastAdministrativeStaffEmailKey;
      case 'super_admin':
        return _lastSuperAdminEmailKey;
      case 'citizen':
      default:
        return _lastCitizenEmailKey;
    }
  }

  static String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'front_desk') {
      return 'administrative_staff';
    }
    if (normalized == 'staff') {
      return 'admin';
    }
    return normalized;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await clearWebAuthStorage(_authStorageKeys);
  }
}
