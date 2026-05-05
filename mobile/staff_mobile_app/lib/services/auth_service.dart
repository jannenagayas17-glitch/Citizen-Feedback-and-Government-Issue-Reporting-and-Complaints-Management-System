import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/token_storage.dart';

class AuthService {
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

      await TokenStorage.saveToken(token);
      await TokenStorage.saveRole(user['role']?.toString() ?? 'citizen');

      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Login failed'));
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? email,
    String? name,
  }) async {
    final response = await http.post(
      _buildUri('/auth/google-login'),
      headers: await _headers(),
      body: jsonEncode({
        'id_token': idToken,
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

      await TokenStorage.saveToken(token);
      await TokenStorage.saveRole(user['role']?.toString() ?? 'citizen');

      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Google login failed'));
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      _buildUri('/auth/register'),
      headers: await _headers(),
      body: jsonEncode({
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
      final token = data['token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;

      if (token == null || user == null) {
        throw Exception('Invalid register response from server');
      }

      await TokenStorage.saveToken(token);
      await TokenStorage.saveRole(user['role']?.toString() ?? 'citizen');

      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Registration failed'));
  }

  Future<Map<String, dynamic>> requestGovernmentAccount({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
    required String department,
    required String jobTitle,
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
        'password_confirmation': passwordConfirmation,
        'department': department,
        'job_title': jobTitle,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = data['token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null && user != null) {
        await TokenStorage.saveToken(token);
        await TokenStorage.saveRole(user['role']?.toString() ?? 'admin');
      }

      return data;
    }

    throw Exception(
      _extractErrorMessage(data, 'Government account request failed'),
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

      Map<String, dynamic>? data;
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      }

      if (response.statusCode == 200 && data != null) {
        return data;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please log in again.');
      }

      throw Exception(
        data == null
            ? 'Failed to fetch user'
            : _extractErrorMessage(data, 'Failed to fetch user'),
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach the server. Make sure Laravel is running on port 8000.',
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

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await http.put(
      _buildUri('/user/password'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to change password'));
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

  Future<Map<String, dynamic>> createManagedAccount({
    required String name,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
    required String role,
    String? department,
    String? jobTitle,
  }) async {
    final response = await http.post(
      _buildUri('/admin/users'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'mobile_number': mobileNumber?.trim() ?? '',
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
        if (jobTitle != null && jobTitle.trim().isNotEmpty)
          'job_title': jobTitle.trim(),
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to create account'));
  }

  Future<Map<String, dynamic>> updateManagedAccount({
    required int id,
    required String name,
    required String email,
    String? mobileNumber,
    required String role,
    String? department,
    String? jobTitle,
    String? password,
    String? passwordConfirmation,
  }) async {
    final response = await http.put(
      _buildUri('/admin/users/$id'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'mobile_number': mobileNumber?.trim() ?? '',
        'role': role,
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
        if (jobTitle != null && jobTitle.trim().isNotEmpty)
          'job_title': jobTitle.trim(),
        if (password != null && password.trim().isNotEmpty) ...{
          'password': password.trim(),
          'password_confirmation': passwordConfirmation?.trim() ?? '',
        },
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to update account'));
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

  Future<Map<String, dynamic>> createOffice({
    required String name,
    String? code,
    String? description,
  }) async {
    final response = await http.post(
      _buildUri('/admin/offices'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name,
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to add office'),
    );
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

  Future<Map<String, dynamic>> deleteAccount(int id) async {
    final response = await http.delete(
      _buildUri('/admin/delete-account/$id'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to delete account'));
  }

  Future<void> logout() async {
    try {
      await http.post(
        _buildUri('/logout'),
        headers: await _headers(authRequired: true),
      );
    } finally {
      await TokenStorage.clearAll();
    }
  }
}
