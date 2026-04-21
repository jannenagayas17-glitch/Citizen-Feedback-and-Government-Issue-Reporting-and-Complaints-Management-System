import 'auth_service.dart';
import 'dashboard_service.dart';
import 'report_service.dart';

class CitizenDataCache {
  CitizenDataCache._();

  static final AuthService _authService = AuthService();
  static final DashboardService _dashboardService = DashboardService();
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

  static Future<Map<String, dynamic>> getUser({bool refresh = false}) async {
    if (!refresh && _user != null) return _user!;
    _user = await _authService.getCurrentUser();
    return _user!;
  }

  static Future<Map<String, dynamic>> getDashboard({
    bool refresh = false,
  }) async {
    if (!refresh && _dashboard != null) return _dashboard!;
    _dashboard = await _dashboardService.getDashboardStats();
    return _dashboard!;
  }

  static Future<List<dynamic>> getReports({bool refresh = false}) async {
    if (!refresh && _reports != null) return _reports!;
    _reports = await _reportService.getReports();
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
      getDashboard(refresh: refresh),
      getReports(refresh: refresh),
    ]);

    return {
      'user': values[0] as Map<String, dynamic>,
      'dashboard': values[1] as Map<String, dynamic>,
      'reports': values[2] as List<dynamic>,
    };
  }

  static void updateUser(Map<String, dynamic> user) {
    _user = Map<String, dynamic>.from(user);
  }

  static void prependReport(Map<String, dynamic> report) {
    final reportId = _extractId(report);
    if (reportId != null) _reportDetails[reportId] = report;
    _reports = [report, ...?_reports];
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
}
