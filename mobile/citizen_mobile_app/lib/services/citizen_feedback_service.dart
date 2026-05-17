import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class CitizenFeedbackService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> getFeedbackEntries() async {
    final response = await _apiClient.get('/feedback', authRequired: true);
    return _decodeEntries(
      response,
      fallbackMessage: 'Failed to fetch feedback history',
    );
  }

  Future<Map<String, dynamic>> saveFeedbackEntry({
    required int officeId,
    int? reportId,
    required String type,
    required String message,
    required int rating,
  }) async {
    final response = await _apiClient.post(
      '/feedback',
      authRequired: true,
      body: {
        'office_id': officeId,
        ...?(reportId == null ? null : {'report_id': reportId}),
        'type': type,
        'message': message,
        'rating': rating,
      },
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded as Map);
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ?? _extractFirstError(decoded),
      );
    }

    throw Exception('Failed to send feedback');
  }

  List<Map<String, dynamic>> _decodeEntries(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is List<dynamic>) {
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : fallbackMessage),
      );
    }

    throw Exception(fallbackMessage);
  }

  String _extractFirstError(Map<String, dynamic> data) {
    final errors = data['errors'];
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

    return 'Failed to send feedback';
  }
}
