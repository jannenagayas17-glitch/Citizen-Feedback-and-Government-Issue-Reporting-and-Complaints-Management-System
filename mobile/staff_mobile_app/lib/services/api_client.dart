import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_storage.dart';

class ApiClient {
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
    return await http.get(
      buildUri(endpoint, queryParameters: queryParameters),
      headers: await getHeaders(authRequired: authRequired),
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) async {
    return await http.post(
      buildUri(endpoint),
      headers: await getHeaders(authRequired: authRequired),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) async {
    return await http.put(
      buildUri(endpoint),
      headers: await getHeaders(authRequired: authRequired),
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
