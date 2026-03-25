import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_storage.dart';
import 'api_client.dart';

class ReportService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getCategories() async {
    final response = await _apiClient.get('/categories', authRequired: true);
    return _decodeListResponse(response, fallbackMessage: 'Failed to fetch categories');
  }

  Future<Map<String, dynamic>> createReport({
    int? categoryId,
    String? categoryName,
    required String title,
    required String description,
    required String location,
    String? barangay,
    String? priority,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.post(
      '/reports',
      authRequired: true,
      body: {
        if (categoryId != null) 'category_id': categoryId,
        if (categoryName != null && categoryName.trim().isNotEmpty)
          'category_name': categoryName.trim(),
        'title': title,
        'description': description,
        'location': location,
        if (barangay != null && barangay.trim().isNotEmpty)
          'barangay': barangay.trim(),
        if (priority != null && priority.trim().isNotEmpty)
          'priority': priority.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to create report'),
    );
  }

  Future<List<dynamic>> getReports() async {
    final response = await _apiClient.get('/reports', authRequired: true);
    return _decodeListResponse(response, fallbackMessage: 'Failed to fetch reports');
  }

  Future<List<dynamic>> getAdminReports({String? status}) async {
    final endpoint = status == null || status.isEmpty
        ? '/admin/reports'
        : '/admin/reports?status=${Uri.encodeComponent(status)}';
    final response = await _apiClient.get(endpoint, authRequired: true);
    return _decodeListResponse(
      response,
      fallbackMessage: 'Failed to fetch admin reports',
    );
  }

  Future<ReportExportFile> exportAdminReports({String? status}) async {
    final endpoint = status == null || status.isEmpty
        ? '/admin/reports/export'
        : '/admin/reports/export?status=${Uri.encodeComponent(status)}';

    final response = await _apiClient.get(endpoint, authRequired: true);

    if (response.statusCode == 200) {
      return ReportExportFile(
        bytes: response.bodyBytes,
        fileName: _extractFilename(response) ??
            'engineering-reports-${DateTime.now().millisecondsSinceEpoch}.csv',
        mimeType: response.headers['content-type'] ?? 'text/csv',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['message']?.toString() ??
            (decoded['errors'] != null
                ? decoded['errors'].toString()
                : 'Failed to export report file'),
      );
    }

    throw Exception('Failed to export report file');
  }

  Future<Map<String, dynamic>> updateReportStatus({
    required int reportId,
    required String status,
    String? remarks,
  }) async {
    final response = await _apiClient.post(
      '/admin/reports/$reportId/status',
      authRequired: true,
      body: {
        'status': status,
        if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to update report status'),
    );
  }

  Future<Map<String, dynamic>> getReportDetail(int id) async {
    final response = await _apiClient.get('/reports/$id', authRequired: true);
    return jsonDecode(response.body);
  }

  List<dynamic> _decodeListResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is List<dynamic>) {
      return decoded;
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

  Future<Map<String, dynamic>> uploadImage({
    required int reportId,
    required XFile imageFile,
  }) async {
    final token = await TokenStorage.getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/reports/$reportId/images'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    final bytes = await imageFile.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: imageFile.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to upload image'),
    );
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

class ReportExportFile {
  const ReportExportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}
