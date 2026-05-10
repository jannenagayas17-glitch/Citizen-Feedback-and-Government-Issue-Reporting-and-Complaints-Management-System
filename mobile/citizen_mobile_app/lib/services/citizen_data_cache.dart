import 'auth_service.dart';
import 'report_service.dart';

class CitizenDataCache {
  CitizenDataCache._();

  static final AuthService _authService = AuthService();
  static final ReportService _reportService = ReportService();

  static Map<String, dynamic>? _user;
  static Map<String, dynamic>? _dashboard;
  static List<dynamic>? _reports;
  static List<dynamic>? _categories;
  static List<dynamic>? _offices;
  static final Map<int, Map<String, dynamic>> _reportDetails = {};

  static Map<String, dynamic>? get cachedUser => _user;
  static Map<String, dynamic>? get cachedDashboard => _dashboard;
  static List<dynamic>? get cachedReports => _reports;
  static List<dynamic>? get cachedCategories => _categories;
  static List<dynamic>? get cachedOffices => _offices;
  static Map<String, dynamic>? get cachedHomePayload {
    if (_user == null || _dashboard == null || _reports == null) return null;

    return {'user': _user!, 'dashboard': _dashboard!, 'reports': _reports!};
  }

  static Future<Map<String, dynamic>> getUser({bool refresh = false}) async {
    if (!refresh && _user != null) return _user!;
    _user = await _authService.getCurrentUser();
    return _user!;
  }

  static Future<Map<String, dynamic>> getDashboard({
    bool refresh = false,
  }) async {
    if (!refresh && _dashboard != null) return _dashboard!;
    final reports = await getReports(refresh: refresh);
    _dashboard = _dashboardFromReports(reports);
    return _dashboard!;
  }

  static Future<List<dynamic>> getReports({bool refresh = false}) async {
    if (!refresh && _reports != null) return _reports!;
    _reports = _dedupeReports(await _reportService.getReports());
    return _reports!;
  }

  static Future<List<dynamic>> getCategories({bool refresh = false}) async {
    if (!refresh && _categories != null) return _categories!;
    _categories = await _reportService.getCategories();
    return _categories!;
  }

  static Future<List<dynamic>> getOffices({bool refresh = false}) async {
    if (!refresh && _offices != null) return _offices!;
    _offices = await _reportService.getOffices();
    return _offices!;
  }

  static Future<Map<String, dynamic>> getReportDetail(
    int reportId, {
    bool refresh = false,
  }) async {
    if (!refresh && _reportDetails.containsKey(reportId)) {
      return _reportDetails[reportId]!;
    }

    final detail = await _reportService.getReportDetail(reportId);
    _reportDetails[reportId] = detail;
    return detail;
  }

  static Future<Map<String, dynamic>> getHomePayload({
    bool refresh = false,
  }) async {
    final values = await Future.wait<dynamic>([
      getUser(refresh: refresh),
      getReports(refresh: refresh),
    ]);
    final reports = _dedupeReports(values[1] as List<dynamic>);
    _reports = reports;
    _dashboard = _dashboardFromReports(reports);

    return {
      'user': values[0] as Map<String, dynamic>,
      'dashboard': _dashboard!,
      'reports': reports,
    };
  }

  static void updateUser(Map<String, dynamic> user) {
    _user = Map<String, dynamic>.from(user);
  }

  static void prependReport(Map<String, dynamic> report) {
    final reportId = _extractId(report);
    if (reportId != null) _reportDetails[reportId] = report;
    _reports = _dedupeReports([report, ...?_reports]);
    _dashboard = _dashboardFromReports(_reports!);
  }

  static void invalidateReports() {
    _reports = null;
    _dashboard = null;
    _reportDetails.clear();
  }

  static void clear() {
    _user = null;
    _dashboard = null;
    _reports = null;
    _categories = null;
    _offices = null;
    _reportDetails.clear();
  }

  static int? _extractId(Map<String, dynamic> report) {
    final rawId = report['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
  }

  static List<dynamic> _dedupeReports(List<dynamic> reports) {
    final orderedReports = <dynamic>[];
    final seenIds = <int>{};

    for (final item in reports) {
      if (item is! Map<String, dynamic>) {
        orderedReports.add(item);
        continue;
      }

      final reportId = _extractId(item);
      if (reportId == null) {
        orderedReports.add(Map<String, dynamic>.from(item));
        continue;
      }

      if (seenIds.add(reportId)) {
        orderedReports.add(Map<String, dynamic>.from(item));
      }
    }

    return orderedReports;
  }

  static Map<String, dynamic> _dashboardFromReports(List<dynamic> reports) {
    var newCount = 0;
    var pendingCount = 0;
    var inProgressCount = 0;
    var resolvedCount = 0;
    var rejectedCount = 0;

    for (final item in reports) {
      if (item is! Map<String, dynamic>) continue;

      switch ((item['status'] ?? 'New').toString()) {
        case 'New':
          newCount++;
          break;
        case 'Pending':
          pendingCount++;
          break;
        case 'In Progress':
          inProgressCount++;
          break;
        case 'Resolved':
          resolvedCount++;
          break;
        case 'Rejected':
          rejectedCount++;
          break;
      }
    }

    return {
      'total_reports': reports.length,
      'new': newCount,
      'pending': pendingCount,
      'in_progress': inProgressCount,
      'resolved': resolvedCount,
      'rejected': rejectedCount,
    };
  }
}
