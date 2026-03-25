import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _lastCitizenEmailKey = 'last_citizen_email';
  static const String _lastAdminEmailKey = 'last_admin_email';
  static const String _lastSuperAdminEmailKey = 'last_super_admin_email';

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
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> saveLastEmailForRole({
    required String role,
    required String email,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKeyForRole(normalizedRole), normalizedEmail);
  }

  static Future<String?> getLastEmailForRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKeyForRole(role.trim().toLowerCase()));
  }

  static String _emailKeyForRole(String role) {
    switch (role) {
      case 'admin':
        return _lastAdminEmailKey;
      case 'super_admin':
        return _lastSuperAdminEmailKey;
      case 'citizen':
      default:
        return _lastCitizenEmailKey;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}
