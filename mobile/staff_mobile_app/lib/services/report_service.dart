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
  }) async {
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

  Future<Map<String, dynamic>> createWalkInReport({
    int? categoryId,
    String? categoryName,
    required int officeId,
    required String title,
    required String description,
    required String location,
    required String barangay,
    required String complainantName,
    required String complainantContactNumber,
    String? complainantEmail,
    required String complainantAddress,
    bool isAnonymous = false,
    DateTime? expectedReturnAt,
    String? priority,
    double? latitude,
    double? longitude,
    List<XFile> attachments = const [],
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please log in again before submitting a walk-in complaint.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/front-desk/reports'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    void addField(String key, String? value) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        request.fields[key] = normalized;
      }
    }

    addField('office_id', '$officeId');
    addField('title', title);
    addField('description', description);
    addField('location', location);
    addField('barangay', barangay);
    addField('walk_in_full_name', complainantName);
    addField('walk_in_contact_number', complainantContactNumber);
    addField('walk_in_email', complainantEmail);
    addField('walk_in_address', complainantAddress);
    request.fields['is_anonymous'] = isAnonymous ? '1' : '0';

    if (categoryId != null) {
      request.fields['category_id'] = '$categoryId';
    }
    addField('category_name', categoryName);
    addField('priority', priority);
    if (latitude != null) {
      request.fields['latitude'] = '$latitude';
    }
    if (longitude != null) {
      request.fields['longitude'] = '$longitude';
    }
    if (expectedReturnAt != null) {
      request.fields['expected_return_at'] = expectedReturnAt.toIso8601String();
    }

    for (final attachment in attachments.take(3)) {
      final fileSize = await attachment.length();
      if (fileSize > maxAttachmentBytes) {
        throw Exception('Attachments must be 50MB or smaller.');
      }

      final bytes = await attachment.readAsBytes();
      final detectedMimeType =
          lookupMimeType(
            attachment.name,
            headerBytes: bytes.take(32).toList(),
          ) ??
          'application/octet-stream';

      request.files.add(
        http.MultipartFile.fromBytes(
          'media[]',
          bytes,
          filename: attachment.name,
          contentType: MediaType.parse(detectedMimeType),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeMapResponse(response.body);

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data != null) {
      return data;
    }

    throw Exception(
      data == null
          ? 'Failed to submit walk-in complaint'
          : data['message']?.toString() ??
                (data['errors'] != null
                    ? data['errors'].toString()
                    : 'Failed to submit walk-in complaint'),
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
    final response = await _apiClient.get(
      '/admin/reports',
      authRequired: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _decodeListResponse(
      response,
      fallbackMessage: 'Failed to fetch admin reports',
    );
  }

  Future<AdminReportPage> getAdminReportsPage({
    int page = 1,
    int perPage = 25,
    bool includeFilters = true,
    String? search,
    String? status,
    String? category,
    String? barangay,
    String? office,
  }) async {
    final response = await _apiClient.get(
      '/admin/reports',
      authRequired: true,
      queryParameters: {
        'paginate': 'true',
        'page': page,
        'per_page': perPage,
        'include_filters': includeFilters ? '1' : '0',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (barangay != null && barangay.trim().isNotEmpty)
          'barangay': barangay.trim(),
        if (office != null && office.trim().isNotEmpty) 'office': office.trim(),
      },
    );

    final data = _decodeMapResponse(response.body);
    if (response.statusCode == 200 && data != null && data['data'] is List) {
      return AdminReportPage.fromJson(data);
    }

    throw Exception(
      data == null
          ? 'Failed to fetch admin reports'
          : data['message']?.toString() ??
                (data['errors'] != null
                    ? data['errors'].toString()
                    : 'Failed to fetch admin reports'),
    );
  }

  Future<AdminReportPage> getFrontDeskReportsPage({
    int page = 1,
    int perPage = 15,
    bool includeFilters = true,
    String? search,
    String? status,
    String? category,
    String? barangay,
  }) async {
    final response = await _apiClient.get(
      '/front-desk/reports',
      authRequired: true,
      queryParameters: {
        'paginate': 'true',
        'page': page,
        'per_page': perPage,
        'include_filters': includeFilters ? '1' : '0',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (barangay != null && barangay.trim().isNotEmpty)
          'barangay': barangay.trim(),
      },
    );

    final data = _decodeMapResponse(response.body);
    if (response.statusCode == 200 && data != null && data['data'] is List) {
      return AdminReportPage.fromJson(data);
    }

    throw Exception(
      data == null
          ? 'Failed to fetch assisted complaints'
          : data['message']?.toString() ??
                (data['errors'] != null
                    ? data['errors'].toString()
                    : 'Failed to fetch assisted complaints'),
    );
  }

  Future<ReportExportFile> exportAdminReports({
    String? search,
    String? status,
    String? category,
    String? barangay,
    String? office,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/admin/reports/export',
      authRequired: true,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (barangay != null && barangay.trim().isNotEmpty)
          'barangay': barangay.trim(),
        if (office != null && office.trim().isNotEmpty) 'office': office.trim(),
        if (datePreset != null && datePreset.trim().isNotEmpty)
          'date_preset': datePreset.trim(),
        if (startDate != null) 'start_date': _formatDateOnly(startDate),
        if (endDate != null) 'end_date': _formatDateOnly(endDate),
      },
    );

    if (response.statusCode == 200) {
      return ReportExportFile(
        bytes: response.bodyBytes,
        fileName:
            _extractFilename(response) ??
            'reports-and-analytics-${DateTime.now().millisecondsSinceEpoch}.xls',
        mimeType:
            response.headers['content-type'] ?? 'application/vnd.ms-excel',
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

  String? _extractFilename(http.Response response) {
    final contentDisposition = response.headers['content-disposition'];
    if (contentDisposition == null) {
      return null;
    }

    final match = RegExp(
      r'filename="?([^\"]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1);
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

  String _formatDateOnly(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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

class AdminReportPage {
  const AdminReportPage({
    required this.reports,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
    required this.availableFilters,
  });

  factory AdminReportPage.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? fallback;
    }

    return AdminReportPage(
      reports: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      currentPage: parseInt(json['current_page'], fallback: 1),
      lastPage: parseInt(json['last_page'], fallback: 1),
      perPage: parseInt(json['per_page'], fallback: 25),
      total: parseInt(json['total']),
      from: parseInt(json['from']),
      to: parseInt(json['to']),
      availableFilters: ReportAvailableFilters.fromJson(
        json['available_filters'] as Map<String, dynamic>?,
      ),
    );
  }

  final List<Map<String, dynamic>> reports;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;
  final ReportAvailableFilters availableFilters;

  bool get hasPreviousPage => currentPage > 1;
  bool get hasNextPage => currentPage < lastPage;
}

class ReportAvailableFilters {
  const ReportAvailableFilters({
    required this.offices,
    required this.categories,
    required this.barangays,
  });

  factory ReportAvailableFilters.fromJson(Map<String, dynamic>? json) {
    List<String> parseList(String key) {
      return (json?[key] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    return ReportAvailableFilters(
      offices: parseList('offices'),
      categories: parseList('categories'),
      barangays: parseList('barangays'),
    );
  }

  final List<String> offices;
  final List<String> categories;
  final List<String> barangays;
}
