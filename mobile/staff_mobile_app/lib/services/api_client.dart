import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/portal_session_controller.dart';
import '../utils/token_storage.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<Map<String, String>> getHeaders({bool authRequired = false}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final token = await TokenStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Uri buildUri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final filtered = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) return;
      final normalized = value.toString().trim();
      if (normalized.isEmpty) return;
      filtered[key] = normalized;
    });

    if (filtered.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: filtered);
  }

  Future<http.Response> get(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _send(
      () async => http.get(
        buildUri(endpoint, queryParameters: queryParameters),
        headers: await getHeaders(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) async {
    return _send(
      () async => http.post(
        buildUri(endpoint),
        headers: await getHeaders(authRequired: authRequired),
        body: body != null ? jsonEncode(body) : null,
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) async {
    return _send(
      () async => http.put(
        buildUri(endpoint),
        headers: await getHeaders(authRequired: authRequired),
        body: body != null ? jsonEncode(body) : null,
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool authRequired,
  }) async {
    try {
      final response = await request().timeout(_requestTimeout);

      if (authRequired && response.statusCode == 401) {
        await PortalSessionController.expireSession(
          message:
              _extractErrorMessage(response.body) ??
              'Session expired. Please log in again.',
        );
      }

      return response;
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on http.ClientException {
      throw Exception(
        'Unable to reach the server. Make sure Laravel is running on port 8000.',
      );
    }
  }

  String? _extractErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }

            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) {
              return text;
            }
          }
        }

        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      return null;
    }

    return null;
  }
}
