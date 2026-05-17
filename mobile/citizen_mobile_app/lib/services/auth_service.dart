import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'google_auth_service.dart';
import '../utils/token_storage.dart';

class AuthSessionExpiredException implements Exception {
  const AuthSessionExpiredException([
    this.message = 'Your session expired. Please log in again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  Future<void> persistSession({
    required String token,
    required Map<String, dynamic> user,
    String fallbackRole = 'citizen',
  }) async {
    await TokenStorage.saveToken(token);
    await TokenStorage.saveRole(user['role']?.toString() ?? fallbackRole);
  }

  Future<void> clearLocalSession() async {
    await TokenStorage.clearAll();
  }

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final errors = data['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    final message = data['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallback;
  }

  Uri _buildUri(String endpoint) {
    return Uri.parse('${ApiConfig.baseUrl}$endpoint');
  }

  Future<Map<String, String>> _headers({bool authRequired = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        _buildUri('/auth/login'),
        headers: await _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token']?.toString();
        final user = data['user'] as Map<String, dynamic>?;

        if (token == null || user == null) {
          throw Exception('Invalid login response from server');
        }

        await persistSession(token: token, user: user);

        return data;
      }

      throw Exception(_extractErrorMessage(data, 'Login failed'));
    } on http.ClientException {
      throw Exception(
        'Unable to reach the login server. Start Laravel on http://127.0.0.1:8000 and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String roleHint,
    String? email,
    String? name,
  }) async {
    try {
      final response = await http.post(
        _buildUri('/auth/google-login'),
        headers: await _headers(),
        body: jsonEncode({
          'id_token': idToken,
          'role_hint': roleHint,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token']?.toString();
        final user = data['user'] as Map<String, dynamic>?;

        if (token == null || user == null) {
          throw Exception('Invalid Google login response from server');
        }

        await persistSession(token: token, user: user);

        return data;
      }

      throw Exception(_extractErrorMessage(data, 'Google login failed'));
    } on http.ClientException {
      throw Exception(
        'Unable to reach the Google login server. Restart the backend and verify that browser API access is allowed.',
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        _buildUri('/auth/register'),
        headers: await _headers(),
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'name': name,
          'email': email,
          if (mobileNumber != null && mobileNumber.isNotEmpty)
            'mobile_number': mobileNumber,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }

      throw Exception(_extractErrorMessage(data, 'Registration failed'));
    } on http.ClientException {
      throw Exception(
        'Unable to reach the registration server. Start Laravel on http://localhost:8000 and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> requestGovernmentAccount({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String department,
    required String jobTitle,
    required String accessCode,
  }) async {
    final response = await http.post(
      _buildUri('/auth/request-government-account'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        if (mobileNumber != null && mobileNumber.isNotEmpty)
          'mobile_number': mobileNumber,
        'password': password,
        'department': department,
        'job_title': jobTitle,
        'access_code': accessCode,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = data['token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null && user != null) {
        await persistSession(token: token, user: user, fallbackRole: 'admin');
      }

      return data;
    }

    throw Exception(
      data['message'] ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Government account request failed'),
    );
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final response = await http.post(
      _buildUri('/forgot-password'),
      headers: await _headers(),
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    final errors = data['errors'];
    if (errors is Map<String, dynamic>) {
      final emailErrors = errors['email'];
      if (emailErrors is List && emailErrors.isNotEmpty) {
        throw Exception(emailErrors.first.toString());
      }
    }

    throw Exception(data['message']?.toString() ?? 'Failed to send reset link');
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        _buildUri('/user'),
        headers: await _headers(authRequired: true),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return data;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        throw const AuthSessionExpiredException();
      }

      if (data is Map<String, dynamic>) {
        throw Exception(_extractErrorMessage(data, 'Failed to fetch user'));
      }

      throw Exception('Failed to fetch user');
    } on AuthSessionExpiredException {
      rethrow;
    } on http.ClientException {
      throw Exception(
        'Unable to reach the server. Start Laravel on http://127.0.0.1:8000 and try again.',
      );
    } on FormatException {
      throw Exception(
        'The server returned an invalid response. Please restart the backend and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? mobileNumber,
  }) async {
    final response = await http.put(
      _buildUri('/user/profile'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'mobile_number': mobileNumber?.trim() ?? '',
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    final errors = data['errors'];
    if (errors is Map<String, dynamic>) {
      final firstEntry = errors.entries
          .cast<MapEntry<String, dynamic>?>()
          .firstWhere((entry) => entry != null, orElse: () => null);
      if (firstEntry != null &&
          firstEntry.value is List &&
          (firstEntry.value as List).isNotEmpty) {
        throw Exception((firstEntry.value as List).first.toString());
      }
    }

    throw Exception(_extractErrorMessage(data, 'Failed to update profile'));
  }

  Future<List<dynamic>> getAdminUsers() async {
    final response = await http.get(
      _buildUri('/admin/users'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is List<dynamic>) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      throw Exception(_extractErrorMessage(data, 'Failed to fetch users'));
    }

    throw Exception('Failed to fetch users');
  }

  Future<List<dynamic>> getOffices({bool includeInactive = false}) async {
    final suffix = includeInactive ? '?include_inactive=1' : '';
    final response = await http.get(
      _buildUri('/offices$suffix'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is List<dynamic>) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      throw Exception(_extractErrorMessage(data, 'Failed to fetch offices'));
    }

    throw Exception('Failed to fetch offices');
  }

  Future<Map<String, dynamic>> verifyAccount(int id) async {
    final response = await http.post(
      _buildUri('/admin/verify-account/$id'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to verify account'));
  }

  Future<Map<String, dynamic>> deactivateAccount(int id) async {
    final response = await http.post(
      _buildUri('/admin/deactivate-account/$id'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to deactivate account'));
  }

  Future<Map<String, dynamic>> reactivateAccount(int id) async {
    final response = await http.post(
      _buildUri('/admin/reactivate-account/$id'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to reactivate account'));
  }

  Future<void> logout() async {
    try {
      await http.post(
        _buildUri('/logout'),
        headers: await _headers(authRequired: true),
      );
    } finally {
      try {
        await GoogleAuthService().signOut();
      } catch (_) {
        // Always clear the local session even if Google/Firebase cleanup fails.
      }
      await TokenStorage.clearAll();
    }
  }
}
