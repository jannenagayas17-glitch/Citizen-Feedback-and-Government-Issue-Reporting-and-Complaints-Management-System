import 'dart:convert';

import 'api_client.dart';

class EscalationService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getEscalations({
    String? escalationStatus,
    String? barangay,
    String? priority,
  }) async {
    final query = <String>[];
    if (escalationStatus != null && escalationStatus.isNotEmpty) {
      query.add('escalation_status=${Uri.encodeComponent(escalationStatus)}');
    }
    if (barangay != null && barangay.isNotEmpty && barangay != 'All Barangays') {
      query.add('barangay=${Uri.encodeComponent(barangay)}');
    }
    if (priority != null && priority.isNotEmpty && priority != 'All Priorities') {
      query.add('priority=${Uri.encodeComponent(priority)}');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';

    final response = await _apiClient.get(
      '/admin/escalations$suffix',
      authRequired: true,
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to fetch escalations'),
      );
    }

    throw Exception('Failed to fetch escalations');
  }

  Future<Map<String, dynamic>> updateEscalation({
    required int reportId,
    required String status,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/admin/escalations/$reportId',
      authRequired: true,
      body: {
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    final decoded = jsonDecode(response.body);

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to update escalation'),
      );
    }

    throw Exception('Failed to update escalation');
  }
}
