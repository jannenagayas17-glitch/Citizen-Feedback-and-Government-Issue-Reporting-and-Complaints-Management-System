import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/portal_session_controller.dart';
import '../utils/token_storage.dart';

class AuthService {
  static const String _passwordEndpoint = '/user/password';
  static Map<String, dynamic>? _cachedCurrentUser;
  static Future<Map<String, dynamic>>? _currentUserFuture;
  static final Map<String, List<dynamic>> _cachedOffices =
      <String, List<dynamic>>{};
  static final Map<String, Future<List<dynamic>>> _officeFutures =
      <String, Future<List<dynamic>>>{};

  static void _clearSessionCaches() {
    _cachedCurrentUser = null;
    _currentUserFuture = null;
    _cachedOffices.clear();
    _officeFutures.clear();
  }

  static Map<String, dynamic> _cloneUser(Map<String, dynamic> user) =>
      Map<String, dynamic>.from(user);

  static List<dynamic> _cloneList(List<dynamic> values) =>
      values.map((value) {
        if (value is Map<String, dynamic>) {
          return Map<String, dynamic>.from(value);
        }
        return value;
      }).toList(growable: false);

  static void _cacheCurrentUser(Map<String, dynamic> user) {
    _cachedCurrentUser = _cloneUser(user);
    _currentUserFuture = null;
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
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
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.post(
      _buildUri('/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': normalizedEmail, 'password': password}),
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
      _cacheCurrentUser(user);

      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Login failed'));
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String roleHint,
    String? email,
    String? name,
  }) async {
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

      await TokenStorage.saveToken(token);
      await TokenStorage.saveRole(user['role']?.toString() ?? 'citizen');
      _cacheCurrentUser(user);

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
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.post(
      _buildUri('/auth/register'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'email': normalizedEmail,
        if (mobileNumber != null && mobileNumber.isNotEmpty)
          'mobile_number': mobileNumber.trim(),
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
      _cacheCurrentUser(user);

      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Registration failed'));
  }

  Future<Map<String, dynamic>> requestGovernmentAccount({
    required String name,
    String? firstName,
    String? lastName,
    required String email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
    required String department,
    required String jobTitle,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.post(
      _buildUri('/auth/request-government-account'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        if (firstName != null && firstName.trim().isNotEmpty)
          'first_name': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'last_name': lastName.trim(),
        'email': normalizedEmail,
        if (mobileNumber != null && mobileNumber.isNotEmpty)
          'mobile_number': mobileNumber.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'department': department.trim(),
        'job_title': jobTitle.trim(),
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = data['token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null && user != null) {
        await TokenStorage.saveToken(token);
        await TokenStorage.saveRole(user['role']?.toString() ?? 'admin');
        _cacheCurrentUser(user);
      }

      return data;
    }

    throw Exception(
      _extractErrorMessage(data, 'Government account request failed'),
    );
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.post(
      _buildUri('/forgot-password'),
      headers: await _headers(),
      body: jsonEncode({'email': normalizedEmail}),
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

  Future<Map<String, dynamic>> getCurrentUser({bool refresh = false}) async {
    if (!refresh && _cachedCurrentUser != null) {
      return _cloneUser(_cachedCurrentUser!);
    }

    if (!refresh && _currentUserFuture != null) {
      final user = await _currentUserFuture!;
      return _cloneUser(user);
    }

    final future = _fetchCurrentUser();
    _currentUserFuture = future;

    try {
      final user = await future;
      return _cloneUser(user);
    } on http.ClientException {
      throw Exception(
        'Unable to reach the server. Make sure Laravel is running on port 8000.',
      );
    } finally {
      if (identical(_currentUserFuture, future)) {
        _currentUserFuture = null;
      }
    }
  }

  Future<Map<String, dynamic>> _fetchCurrentUser() async {
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
      _cacheCurrentUser(data);
      return _cloneUser(data);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _clearSessionCaches();
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please log in again.');
    }

    throw Exception(
      data == null
          ? 'Failed to fetch user'
          : _extractErrorMessage(data, 'Failed to fetch user'),
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? mobileNumber,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.put(
      _buildUri('/user/profile'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name,
        'email': normalizedEmail,
        'mobile_number': mobileNumber?.trim() ?? '',
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        _cacheCurrentUser(user);
      } else {
        _cachedCurrentUser = null;
      }
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
    final payload = <String, dynamic>{
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPasswordConfirmation,
    };

    var response = await http.put(
      _buildUri(_passwordEndpoint),
      headers: await _headers(authRequired: true),
      body: jsonEncode(payload),
    );
    var data = _decodeMapResponse(response.body);

    if (_shouldRetryPasswordChange(response, data)) {
      response = await http.post(
        _buildUri(_passwordEndpoint),
        headers: await _headers(authRequired: true),
        body: jsonEncode(payload),
      );
      data = _decodeMapResponse(response.body);
    }

    if (response.statusCode == 200 && data != null) {
      return data;
    }

    throw Exception(
      data == null
          ? 'Failed to change password'
          : _extractErrorMessage(data, 'Failed to change password'),
    );
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
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.post(
      _buildUri('/admin/users'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name.trim(),
        'email': normalizedEmail,
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
    final normalizedEmail = _normalizeEmail(email);
    final response = await http.put(
      _buildUri('/admin/users/$id'),
      headers: await _headers(authRequired: true),
      body: jsonEncode({
        'name': name.trim(),
        'email': normalizedEmail,
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
      _cachedCurrentUser = null;
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to update account'));
  }

  Future<List<dynamic>> getOffices({
    bool includeInactive = false,
    bool refresh = false,
  }) async {
    final cacheKey = includeInactive ? 'with-inactive' : 'active-only';
    if (!refresh && _cachedOffices.containsKey(cacheKey)) {
      return _cloneList(_cachedOffices[cacheKey]!);
    }

    if (!refresh && _officeFutures.containsKey(cacheKey)) {
      final offices = await _officeFutures[cacheKey]!;
      return _cloneList(offices);
    }

    final future = _fetchOffices(
      includeInactive: includeInactive,
      cacheKey: cacheKey,
    );
    _officeFutures[cacheKey] = future;

    try {
      final offices = await future;
      return _cloneList(offices);
    } finally {
      if (identical(_officeFutures[cacheKey], future)) {
        _officeFutures.remove(cacheKey);
      }
    }
  }

  Future<List<dynamic>> _fetchOffices({
    required bool includeInactive,
    required String cacheKey,
  }) async {
    final suffix = includeInactive ? '?include_inactive=1' : '';
    final response = await http.get(
      _buildUri('/offices$suffix'),
      headers: await _headers(authRequired: true),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is List<dynamic>) {
      final offices = _cloneList(data);
      _cachedOffices[cacheKey] = offices;
      return offices;
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
      _cachedOffices.clear();
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
      _cachedCurrentUser = null;
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
      _cachedCurrentUser = null;
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
      _cachedCurrentUser = null;
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
      _cachedCurrentUser = null;
      return data;
    }

    throw Exception(_extractErrorMessage(data, 'Failed to delete account'));
  }

  Future<void> logout() async {
    final token = await TokenStorage.getToken();
    _clearSessionCaches();

    await PortalSessionController.clearStoredSession(signOutGoogle: true);

    if (token != null && token.trim().isNotEmpty) {
      unawaited(_sendLogoutRequest(token.trim()));
    }
  }

  Map<String, dynamic>? _decodeMapResponse(String responseBody) {
    final trimmedBody = responseBody.trim();
    if (trimmedBody.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  bool _shouldRetryPasswordChange(
    http.Response response,
    Map<String, dynamic>? data,
  ) {
    if (response.statusCode == 404 || response.statusCode == 405) {
      return true;
    }

    final message = data?['message']?.toString().toLowerCase() ?? '';
    return message.contains('route') && message.contains('user/password');
  }

  Future<void> _sendLogoutRequest(String token) async {
    try {
      await http
          .post(
            _buildUri('/logout'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Local logout has already completed. Remote logout failures must not
      // block portal sign-out.
    }
  }
}
