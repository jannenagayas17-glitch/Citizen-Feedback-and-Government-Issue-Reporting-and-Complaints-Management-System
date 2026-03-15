import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/token_storage.dart';

class AuthService {
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
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
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

    throw Exception(
      data['message'] ??
          (data['errors'] != null ? data['errors'].toString() : 'Login failed'),
    );
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
        if (email != null) 'email': email,
        if (name != null) 'name': name,
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

    throw Exception(
      data['message'] ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Google login failed'),
    );
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

    throw Exception(
      data['message'] ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Registration failed'),
    );
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
        await TokenStorage.saveToken(token);
        await TokenStorage.saveRole(user['role']?.toString() ?? 'admin');
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

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      _buildUri('/forgot-password'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['message'] ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to send reset link'),
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      _buildUri('/user'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }

    throw Exception('Failed to fetch user');
  }

  Future<List<dynamic>> getAdminUsers() async {
    final response = await http.get(
      _buildUri('/admin/users'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as List<dynamic>;
    }

    throw Exception('Failed to fetch users');
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

    throw Exception(data['message']?.toString() ?? 'Failed to verify account');
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

    throw Exception(
      data['message']?.toString() ?? 'Failed to deactivate account',
    );
  }

  Future<void> logout() async {
    final response = await http.post(
      _buildUri('/logout'),
      headers: await _headers(authRequired: true),
    );

    if (response.statusCode == 200) {
      await TokenStorage.clearAll();
      return;
    }

    await TokenStorage.clearAll();
    throw Exception('Logout failed');
  }
}
