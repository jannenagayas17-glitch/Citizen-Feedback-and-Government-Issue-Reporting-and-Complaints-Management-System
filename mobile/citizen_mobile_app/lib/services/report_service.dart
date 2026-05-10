import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../config/api_config.dart';
import '../utils/token_storage.dart';
import 'api_client.dart';

class ReportService {
  static const int maxAttachmentBytes = 50 * 1024 * 1024;

  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getCategories() async {
    final response = await _apiClient.get('/categories', authRequired: true);
    return _decodeListResponse(
      response,
      fallbackMessage: 'Failed to fetch categories',
    );
  }

  Future<List<dynamic>> getOffices() async {
    final response = await _apiClient.get('/offices', authRequired: true);
    return _decodeListResponse(
      response,
      fallbackMessage: 'Failed to fetch offices',
    );
  }

  Future<Map<String, dynamic>> createReport({
    int? categoryId,
    String? categoryName,
    int? officeId,
    required String title,
    required String description,
    required String location,
    String? barangay,
    String? priority,
    double? latitude,
    double? longitude,
    List<XFile> mediaFiles = const <XFile>[],
  }) async {
    if (mediaFiles.isNotEmpty) {
      return _createMultipartReport(
        categoryId: categoryId,
        categoryName: categoryName,
        officeId: officeId,
        title: title,
        description: description,
        location: location,
        barangay: barangay,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
        mediaFiles: mediaFiles,
      );
    }

    final response = await _apiClient.post(
      '/reports',
      authRequired: true,
      body: _buildReportPayload(
        categoryId: categoryId,
        categoryName: categoryName,
        officeId: officeId,
        title: title,
        description: description,
        location: location,
        barangay: barangay,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
      ),
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

  Future<Map<String, dynamic>> requestSubmissionVerification({
    int? categoryId,
    String? categoryName,
    int? officeId,
    required String title,
    required String description,
    required String location,
    String? barangay,
    String? priority,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.post(
      '/reports/request-verification',
      authRequired: true,
      body: _buildReportPayload(
        categoryId: categoryId,
        categoryName: categoryName,
        officeId: officeId,
        title: title,
        description: description,
        location: location,
        barangay: barangay,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to send verification code'),
    );
  }

  Future<Map<String, dynamic>> verifySubmissionAndCreateReport({
    required String otp,
  }) async {
    final response = await _apiClient.post(
      '/reports/verify-and-store',
      authRequired: true,
      body: {'otp': otp},
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ??
          (data['errors'] != null
              ? data['errors'].toString()
              : 'Failed to verify submission'),
    );
  }

  Future<List<dynamic>> getReports() async {
    final response = await _apiClient.get('/reports', authRequired: true);
    return _decodeListResponse(
      response,
      fallbackMessage: 'Failed to fetch reports',
    );
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
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
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

  Future<Map<String, dynamic>> uploadMedia({
    required int reportId,
    required XFile mediaFile,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please log in again before uploading attachments.');
    }

    final fileSize = await mediaFile.length();
    if (fileSize > maxAttachmentBytes) {
      throw Exception('Attachments must be 50MB or smaller.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/reports/$reportId/images'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    final bytes = await mediaFile.readAsBytes();
    final detectedMimeType =
        lookupMimeType(mediaFile.name, headerBytes: bytes.take(32).toList()) ??
        'application/octet-stream';
    request.files.add(
      http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: mediaFile.name,
        contentType: MediaType.parse(detectedMimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeMapResponse(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data ?? <String, dynamic>{};
    }

    throw Exception(
      data == null
          ? 'Failed to upload attachment (HTTP ${response.statusCode})'
          : data['message']?.toString() ??
                (data['errors'] != null
                    ? data['errors'].toString()
                    : 'Failed to upload attachment'),
    );
  }

  Future<Map<String, dynamic>> _createMultipartReport({
    int? categoryId,
    String? categoryName,
    int? officeId,
    required String title,
    required String description,
    required String location,
    String? barangay,
    String? priority,
    double? latitude,
    double? longitude,
    required List<XFile> mediaFiles,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please log in again before submitting a report.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/reports'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(
      _buildReportPayload(
        categoryId: categoryId,
        categoryName: categoryName,
        officeId: officeId,
        title: title,
        description: description,
        location: location,
        barangay: barangay,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
      ).map((key, value) => MapEntry(key, value.toString())),
    );

    for (final mediaFile in mediaFiles) {
      final fileSize = await mediaFile.length();
      if (fileSize > maxAttachmentBytes) {
        throw Exception('Attachments must be 50MB or smaller.');
      }

      final bytes = await mediaFile.readAsBytes();
      final detectedMimeType =
          lookupMimeType(
            mediaFile.name,
            headerBytes: bytes.take(32).toList(),
          ) ??
          'application/octet-stream';

      request.files.add(
        http.MultipartFile.fromBytes(
          'media[]',
          bytes,
          filename: mediaFile.name,
          contentType: MediaType.parse(detectedMimeType),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeMapResponse(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data ?? <String, dynamic>{};
    }

    throw Exception(
      data == null
          ? 'Failed to create report (HTTP ${response.statusCode})'
          : data['message']?.toString() ??
                (data['errors'] != null
                    ? data['errors'].toString()
                    : 'Failed to create report'),
    );
  }

  Map<String, dynamic> _buildReportPayload({
    int? categoryId,
    String? categoryName,
    int? officeId,
    required String title,
    required String description,
    required String location,
    String? barangay,
    String? priority,
    double? latitude,
    double? longitude,
  }) {
    final normalizedCategoryName = categoryName?.trim();
    final normalizedBarangay = barangay?.trim();
    final normalizedPriority = priority?.trim();
    final categoryNameValue =
        normalizedCategoryName == null || normalizedCategoryName.isEmpty
        ? null
        : normalizedCategoryName;
    final barangayValue =
        normalizedBarangay == null || normalizedBarangay.isEmpty
        ? null
        : normalizedBarangay;
    final priorityValue =
        normalizedPriority == null || normalizedPriority.isEmpty
        ? null
        : normalizedPriority;

    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
    };

    if (categoryId != null) payload['category_id'] = categoryId;
    if (categoryNameValue != null) payload['category_name'] = categoryNameValue;
    if (officeId != null) payload['office_id'] = officeId;
    if (barangayValue != null) payload['barangay'] = barangayValue;
    if (priorityValue != null) payload['priority'] = priorityValue;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;

    return payload;
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
}
