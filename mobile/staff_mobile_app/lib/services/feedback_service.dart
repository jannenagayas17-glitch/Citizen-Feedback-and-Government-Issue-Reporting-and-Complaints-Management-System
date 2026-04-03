import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class FeedbackService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> getFeedbackEntries({
    int? days,
    String? type,
    String? barangay,
  }) async {
    final query = <String>[
      if (days != null) 'days=$days',
      if (type != null && type.isNotEmpty && type != 'All Feedback')
        'type=${Uri.encodeComponent(type)}',
      if (barangay != null && barangay.isNotEmpty && barangay != 'All Barangays')
        'barangay=${Uri.encodeComponent(barangay)}',
    ].join('&');

    final endpoint = query.isEmpty ? '/feedback' : '/feedback?$query';
    final response = await _apiClient.get(endpoint, authRequired: true);
    return _decodeEntries(
      response,
      fallbackMessage: 'Failed to fetch citizen feedback',
    );
  }

  Future<FeedbackExportFile> exportFeedback({
    int? days,
    String? type,
    String? barangay,
  }) async {
    final query = <String>[
      if (days != null) 'days=$days',
      if (type != null && type.isNotEmpty && type != 'All Feedback')
        'type=${Uri.encodeComponent(type)}',
      if (barangay != null && barangay.isNotEmpty && barangay != 'All Barangays')
        'barangay=${Uri.encodeComponent(barangay)}',
    ].join('&');

    final endpoint = query.isEmpty ? '/feedback/export' : '/feedback/export?$query';
    final response = await _apiClient.get(endpoint, authRequired: true);

    if (response.statusCode == 200) {
      return FeedbackExportFile(
        bytes: response.bodyBytes,
        fileName: _extractFilename(response) ??
            'citizen-feedback-${DateTime.now().millisecondsSinceEpoch}.csv',
        mimeType: response.headers['content-type'] ?? 'text/csv',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to export citizen feedback'),
      );
    }

    throw Exception('Failed to export citizen feedback');
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
            (entry) => entry.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
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

  String? _extractFilename(http.Response response) {
    final contentDisposition = response.headers['content-disposition'];
    if (contentDisposition == null) {
      return null;
    }

    final match = RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
    return match?.group(1);
  }
}

class FeedbackExportFile {
  const FeedbackExportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}
