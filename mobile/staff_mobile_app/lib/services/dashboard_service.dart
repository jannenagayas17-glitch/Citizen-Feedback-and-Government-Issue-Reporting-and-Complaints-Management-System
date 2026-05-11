import 'dart:convert';
import 'api_client.dart';

class DashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _apiClient.get('/dashboard', authRequired: true);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getAnalytics({
    String? office,
    String? barangay,
    String? category,
    String? status,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/admin/analytics',
      authRequired: true,
      queryParameters: {
        if (office != null && office.trim().isNotEmpty) 'office': office.trim(),
        if (barangay != null && barangay.trim().isNotEmpty)
          'barangay': barangay.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (datePreset != null && datePreset.trim().isNotEmpty)
          'date_preset': datePreset.trim(),
        if (startDate != null) 'start_date': _formatDateOnly(startDate),
        if (endDate != null) 'end_date': _formatDateOnly(endDate),
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _formatDateOnly(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
