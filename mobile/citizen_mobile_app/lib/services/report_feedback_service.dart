import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReportFeedbackService {
  static const String _ratingsKey = 'citizen_report_ratings';

  static String buildTrackingId(int reportId) {
    return 'TCF-${reportId.toString().padLeft(6, '0')}';
  }

  static Future<Map<String, int>> getRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratingsKey);
    if (raw == null || raw.isEmpty) {
      return <String, int>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, int>{};
    }

    return decoded.map(
      (key, value) => MapEntry(key, int.tryParse('$value') ?? 0),
    )..removeWhere((_, value) => value < 1 || value > 5);
  }

  static Future<int?> getRatingForReport(int reportId) async {
    final ratings = await getRatings();
    return ratings['$reportId'];
  }

  static Future<void> saveRating({
    required int reportId,
    required int rating,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ratings = await getRatings();
    ratings['$reportId'] = rating.clamp(1, 5);
    await prefs.setString(_ratingsKey, jsonEncode(ratings));
  }
}
