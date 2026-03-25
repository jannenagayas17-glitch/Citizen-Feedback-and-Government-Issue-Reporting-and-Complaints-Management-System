import 'dart:convert';
import 'api_client.dart';

class DashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _apiClient.get('/dashboard', authRequired: true);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _apiClient.get('/admin/analytics', authRequired: true);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
