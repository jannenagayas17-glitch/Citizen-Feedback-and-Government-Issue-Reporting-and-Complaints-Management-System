import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class FeedbackService {
  final ApiClient _apiClient = ApiClient();

  Future<FeedbackPage> getFeedbackPage({
    int page = 1,
    int perPage = 20,
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/feedback',
      authRequired: true,
      queryParameters: {
        'paginate': '1',
        'page': page,
        'per_page': perPage,
        ..._filterQueryParameters(
          search: search,
          type: type,
          barangay: barangay,
          office: office,
          rating: rating,
          datePreset: datePreset,
          startDate: startDate,
          endDate: endDate,
        ),
      },
    );

    final data = _decodeMapResponse(response.body);
    if (response.statusCode == 200 && data != null && data['data'] is List) {
      return FeedbackPage.fromJson(data);
    }

    throw Exception(
      data == null
          ? 'Failed to fetch citizen feedback'
          : _extractErrorMessage(data, 'Failed to fetch citizen feedback'),
    );
  }

  Future<FeedbackSummaryData> getFeedbackSummary({
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/feedback/summary',
      authRequired: true,
      queryParameters: _filterQueryParameters(
        search: search,
        type: type,
        barangay: barangay,
        office: office,
        rating: rating,
        datePreset: datePreset,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    final data = _decodeMapResponse(response.body);
    if (response.statusCode == 200 && data != null) {
      return FeedbackSummaryData.fromJson(data);
    }

    throw Exception(
      data == null
          ? 'Failed to fetch feedback summary'
          : _extractErrorMessage(data, 'Failed to fetch feedback summary'),
    );
  }

  Future<FeedbackChartsData> getFeedbackCharts({
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/feedback/charts',
      authRequired: true,
      queryParameters: _filterQueryParameters(
        search: search,
        type: type,
        barangay: barangay,
        office: office,
        rating: rating,
        datePreset: datePreset,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    final data = _decodeMapResponse(response.body);
    if (response.statusCode == 200 && data != null) {
      return FeedbackChartsData.fromJson(data);
    }

    throw Exception(
      data == null
          ? 'Failed to fetch feedback charts'
          : _extractErrorMessage(data, 'Failed to fetch feedback charts'),
    );
  }

  Future<FeedbackExportFile> exportFeedback({
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      '/feedback/export',
      authRequired: true,
      queryParameters: _filterQueryParameters(
        search: search,
        type: type,
        barangay: barangay,
        office: office,
        rating: rating,
        datePreset: datePreset,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    if (response.statusCode == 200) {
      return FeedbackExportFile(
        bytes: response.bodyBytes,
        fileName:
            _extractFilename(response) ??
            'citizen-feedback-${DateTime.now().millisecondsSinceEpoch}.csv',
        mimeType: response.headers['content-type'] ?? 'text/csv',
      );
    }

    final decoded = _decodeMapResponse(response.body);
    throw Exception(
      decoded == null
          ? 'Failed to export citizen feedback'
          : _extractErrorMessage(decoded, 'Failed to export citizen feedback'),
    );
  }

  Map<String, dynamic> _filterQueryParameters({
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final normalizedDatePreset = datePreset?.trim();

    return {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (type != null && type.trim().isNotEmpty && type != 'All Feedback')
        'type': type.trim(),
      if (barangay != null &&
          barangay.trim().isNotEmpty &&
          barangay != 'All Barangays')
        'barangay': barangay.trim(),
      if (office != null &&
          office.trim().isNotEmpty &&
          office != 'All Departments')
        'office': office.trim(),
      ...?switch (rating) {
        final value? => {'rating': value},
        null => null,
      },
      if (normalizedDatePreset?.isNotEmpty ?? false)
        'date_preset': normalizedDatePreset,
      if (startDate != null) 'start_date': _formatDateOnly(startDate),
      if (endDate != null) 'end_date': _formatDateOnly(endDate),
    };
  }

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
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

    final message = data['message']?.toString().trim();
    return message == null || message.isEmpty ? fallback : message;
  }

  String? _extractFilename(http.Response response) {
    final contentDisposition = response.headers['content-disposition'];
    if (contentDisposition == null) {
      return null;
    }

    final match = RegExp(
      r'filename="?([^"]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1);
  }

  Map<String, dynamic>? _decodeMapResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
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

class FeedbackSummaryData {
  const FeedbackSummaryData({
    required this.totalFeedback,
    required this.averageRating,
    required this.recentFeedbackCount,
    required this.typeCounts,
    required this.typeBreakdown,
    required this.availableFilters,
  });

  factory FeedbackSummaryData.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['type_breakdown'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FeedbackBreakdownItem.fromJson)
        .toList();

    return FeedbackSummaryData(
      totalFeedback: _parseInt(json['total_feedback']),
      averageRating: _parseDouble(json['average_rating']),
      recentFeedbackCount: _parseInt(json['recent_feedback_count']),
      typeCounts: {for (final item in breakdown) item.label: item.count},
      typeBreakdown: breakdown,
      availableFilters: FeedbackAvailableFilters.fromJson(
        json['available_filters'] as Map<String, dynamic>?,
      ),
    );
  }

  final int totalFeedback;
  final double averageRating;
  final int recentFeedbackCount;
  final Map<String, int> typeCounts;
  final List<FeedbackBreakdownItem> typeBreakdown;
  final FeedbackAvailableFilters availableFilters;

  bool get hasData => totalFeedback > 0;
}

class FeedbackChartsData {
  const FeedbackChartsData({
    required this.ratingBreakdown,
    required this.typeBreakdown,
    required this.officeBreakdown,
    required this.barangayBreakdown,
    required this.trendBreakdown,
  });

  factory FeedbackChartsData.fromJson(Map<String, dynamic> json) {
    List<FeedbackBreakdownItem> parseBreakdown(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FeedbackBreakdownItem.fromJson)
            .toList();

    final ratings = (json['rating_breakdown'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FeedbackRatingBreakdownItem.fromJson)
        .toList();

    final trend = (json['trend_breakdown'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FeedbackTrendPoint.fromJson)
        .toList();

    return FeedbackChartsData(
      ratingBreakdown: ratings,
      typeBreakdown: parseBreakdown('type_breakdown'),
      officeBreakdown: parseBreakdown('office_breakdown'),
      barangayBreakdown: parseBreakdown('barangay_breakdown'),
      trendBreakdown: trend,
    );
  }

  final List<FeedbackRatingBreakdownItem> ratingBreakdown;
  final List<FeedbackBreakdownItem> typeBreakdown;
  final List<FeedbackBreakdownItem> officeBreakdown;
  final List<FeedbackBreakdownItem> barangayBreakdown;
  final List<FeedbackTrendPoint> trendBreakdown;
}

class FeedbackPage {
  const FeedbackPage({
    required this.entries,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
  });

  factory FeedbackPage.fromJson(Map<String, dynamic> json) {
    return FeedbackPage(
      entries: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      currentPage: _parseInt(json['current_page'], fallback: 1),
      lastPage: _parseInt(json['last_page'], fallback: 1),
      perPage: _parseInt(json['per_page'], fallback: 20),
      total: _parseInt(json['total']),
      from: _parseInt(json['from']),
      to: _parseInt(json['to']),
    );
  }

  final List<Map<String, dynamic>> entries;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;

  bool get hasPreviousPage => currentPage > 1;
  bool get hasNextPage => currentPage < lastPage;
}

class FeedbackAvailableFilters {
  const FeedbackAvailableFilters({
    required this.offices,
    required this.barangays,
  });

  factory FeedbackAvailableFilters.fromJson(Map<String, dynamic>? json) {
    List<String> parseList(String key) {
      return (json?[key] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    return FeedbackAvailableFilters(
      offices: parseList('offices'),
      barangays: parseList('barangays'),
    );
  }

  final List<String> offices;
  final List<String> barangays;
}

class FeedbackBreakdownItem {
  const FeedbackBreakdownItem({required this.label, required this.count});

  factory FeedbackBreakdownItem.fromJson(Map<String, dynamic> json) {
    return FeedbackBreakdownItem(
      label: (json['label'] ?? '').toString(),
      count: _parseInt(json['count']),
    );
  }

  final String label;
  final int count;
}

class FeedbackRatingBreakdownItem extends FeedbackBreakdownItem {
  const FeedbackRatingBreakdownItem({
    required super.label,
    required super.count,
    required this.rating,
  });

  factory FeedbackRatingBreakdownItem.fromJson(Map<String, dynamic> json) {
    return FeedbackRatingBreakdownItem(
      label: (json['label'] ?? '').toString(),
      count: _parseInt(json['count']),
      rating: _parseInt(json['rating']),
    );
  }

  final int rating;
}

class FeedbackTrendPoint {
  const FeedbackTrendPoint({
    required this.label,
    required this.count,
    required this.averageRating,
  });

  factory FeedbackTrendPoint.fromJson(Map<String, dynamic> json) {
    return FeedbackTrendPoint(
      label: (json['label'] ?? '').toString(),
      count: _parseInt(json['count']),
      averageRating: _parseDouble(json['average_rating']),
    );
  }

  final String label;
  final int count;
  final double averageRating;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? fallback;
}

double _parseDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? fallback;
}
