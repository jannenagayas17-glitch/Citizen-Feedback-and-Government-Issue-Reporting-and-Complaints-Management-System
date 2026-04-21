import 'dart:convert';

import 'api_client.dart';

class SystemSettingsService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.get(
      '/admin/settings',
      authRequired: true,
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        decoded['settings'] as Map? ?? const <String, dynamic>{},
      );
    }

    if (decoded is Map<String, dynamic>) {
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
    final response = await _apiClient.put(
      '/admin/settings',
      authRequired: true,
      body: settings,
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        decoded['settings'] as Map? ?? const <String, dynamic>{},
      );
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to update settings'),
      );
    }

    throw Exception('Failed to update settings');
  }
}
