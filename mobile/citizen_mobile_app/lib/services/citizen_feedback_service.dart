import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CitizenFeedbackService {
  static const String _storageKey = 'citizen_general_feedback_entries';

  static Future<List<Map<String, dynamic>>> getFeedbackEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    return decoded
        .whereType<Map>()
        .map((entry) => entry.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }

  static Future<void> saveFeedbackEntry({
    required String type,
    required String officeName,
    required String message,
    required int rating,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getFeedbackEntries();

    entries.insert(0, <String, dynamic>{
      'type': type,
      'office_name': officeName,
      'message': message,
      'rating': rating.clamp(1, 5),
      'submitted_at': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_storageKey, jsonEncode(entries));
  }
}
