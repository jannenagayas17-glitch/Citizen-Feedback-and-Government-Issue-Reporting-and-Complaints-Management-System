import 'dart:convert';

import 'api_client.dart';

class SystemSettingsService {
  static const String _settingsEndpoint = '/admin/settings';
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.get(
      _settingsEndpoint,
      authRequired: true,
    );
    final decoded = _decodeMapResponse(response.body);

    if (response.statusCode == 200 && decoded != null) {
      return Map<String, dynamic>.from(
        decoded['settings'] as Map? ?? const <String, dynamic>{},
      );
    }

    if (decoded != null) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to fetch settings'),
      );
    }

    throw Exception('Failed to fetch settings');
  }

  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    var response = await _apiClient.put(
      _settingsEndpoint,
      authRequired: true,
      body: settings,
    );
    var decoded = _decodeMapResponse(response.body);

    if (_shouldRetrySettingsUpdate(response.statusCode, decoded)) {
      response = await _apiClient.post(
        _settingsEndpoint,
        authRequired: true,
        body: settings,
      );
      decoded = _decodeMapResponse(response.body);
    }

    if (response.statusCode == 200 && decoded != null) {
      return Map<String, dynamic>.from(
        decoded['settings'] as Map? ?? const <String, dynamic>{},
      );
    }

    if (decoded != null) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to update settings'),
      );
    }

    throw Exception('Failed to update settings');
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

  bool _shouldRetrySettingsUpdate(int statusCode, Map<String, dynamic>? data) {
    if (statusCode == 404 || statusCode == 405) {
      return true;
    }

    final message = data?['message']?.toString().toLowerCase() ?? '';
    return message.contains('route') && message.contains('admin/settings');
  }
}
