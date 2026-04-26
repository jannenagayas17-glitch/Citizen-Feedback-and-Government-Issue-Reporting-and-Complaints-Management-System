import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../services/system_settings_service.dart';
import '../admin/analytics_reports_screen.dart';
import '../auth/login_screen.dart';
import '../admin/complaint_management_screen.dart';
import '../../utils/admin_theme.dart';
import 'escalation_management_screen.dart';
import 'feedback_management_screen.dart';
import 'manage_admins_screen.dart';
import 'manage_offices_screen.dart';
import 'system_settings_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

enum _SuperAdminDesktopSection {
  dashboard,
  reports,
  analytics,
  feedback,
  settings,
  users,
  offices,
  escalations,
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  final SystemSettingsService _settingsService = SystemSettingsService();

  late Future<_SuperDashboardData> _statsFuture;
  _SuperDashboardData? _cachedDashboardData;
  bool _refreshingDashboard = false;
  _SuperAdminDesktopSection _desktopSection =
      _SuperAdminDesktopSection.dashboard;
  final Set<_SuperAdminDesktopSection> _loadedDesktopSections = {};

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadAndCacheDashboard();
  }

  Future<_SuperDashboardData> _loadAndCacheDashboard() async {
    final results = await Future.wait([
      _authService.getCurrentUser(),
      _reportService.getAdminReports(),
      _authService.getAdminUsers(),
      _authService.getOffices(includeInactive: true),
      _settingsService.getSettings(),
    ]);
    final user = Map<String, dynamic>.from(results[0] as Map);
    final reports = (results[1] as List)
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final users = (results[2] as List)
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final offices = (results[3] as List)
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final settings = Map<String, dynamic>.from(results[4] as Map);

    final data = _SuperDashboardData(
      user: user,
      reports: reports,
      users: users,
      offices: offices,
      settings: settings,
    );
    _cachedDashboardData = data;

    return data;
  }

  Future<void> _refresh() async {
    final future = _loadAndCacheDashboard();
    setState(() {
      _refreshingDashboard = true;
      _statsFuture = future;
    });
    try {
      await future;
    } finally {
      if (mounted) {
        setState(() => _refreshingDashboard = false);
      }
    }
  }

  bool _isDesktopLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  void _selectDesktopSection(_SuperAdminDesktopSection section) {
    if (_desktopSection == section) {
      return;
    }

    if (section != _SuperAdminDesktopSection.dashboard) {
      _cacheDesktopSection(section);
    }

    setState(() {
      _desktopSection = section;
    });
  }

  void _cacheDesktopSection(_SuperAdminDesktopSection section) {
    if (section == _SuperAdminDesktopSection.dashboard) {
      return;
    }

    _loadedDesktopSections.add(section);
  }

  void _showDashboard() {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.dashboard);
      return;
    }
    _refresh();
  }

  Future<void> _openReports() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.reports);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ComplaintManagementScreen()),
    );
    await _refresh();
  }

  Future<void> _openUsers() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.users);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageAdminsScreen()),
    );
    await _refresh();
  }

  Future<void> _openOffices() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.offices);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageOfficesScreen()),
    );
    await _refresh();
  }

  Future<void> _openAnalytics() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.analytics);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsReportsScreen()),
    );
    await _refresh();
  }

  Future<void> _openFeedback() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.feedback);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackManagementScreen()),
    );
    await _refresh();
  }

  Future<void> _openSettings() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.settings);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SystemSettingsScreen()),
    );
    await _refresh();
  }

  Future<void> _openEscalations() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_SuperAdminDesktopSection.escalations);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EscalationManagementScreen()),
    );
    await _refresh();
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  DateTime? _reportCreatedAt(Map<String, dynamic> report) {
    final raw = report['created_at']?.toString();
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  String _reportStatus(Map<String, dynamic> report) =>
      (report['status'] ?? 'New').toString();

  String _reportPriority(Map<String, dynamic> report) =>
      (report['priority'] ?? 'Normal').toString();

  String _reportOfficeName(Map<String, dynamic> report) {
    final office = report['office'];
    if (office is Map<String, dynamic>) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Unassigned Office';
  }

  String _reportBarangay(Map<String, dynamic> report) =>
      (report['barangay'] ?? '').toString().trim();

  double? _barangayNumber(String value) {
    final match = RegExp(
      r'^barangay\s+(\d+)(?:-([a-z]))?',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final suffix = match.group(2);
    if (suffix == null) return number;
    return number + ((suffix.toLowerCase().codeUnitAt(0) - 96) / 10);
  }

  Offset _heatMapPositionForBarangay(String barangay, int index) {
    final number = _barangayNumber(barangay);
    final normalized = barangay.toLowerCase();
    var x = 0.50;
    var y = 0.50;

    if (number != null) {
      if (number <= 30) {
        x = 0.30;
        y = 0.30;
      } else if (number <= 56) {
        x = 0.42;
        y = 0.48;
      } else if (number <= 74) {
        x = 0.28;
        y = 0.66;
      } else if (number <= 90) {
        x = 0.66;
        y = 0.68;
      } else {
        x = 0.72;
        y = 0.40;
      }
    } else if (normalized.contains('san jose')) {
      x = 0.70;
      y = 0.70;
    } else if (normalized.contains('sagkahan')) {
      x = 0.36;
      y = 0.62;
    } else if (normalized.contains('downtown') || normalized.contains('real')) {
      x = 0.34;
      y = 0.36;
    }

    final hash = barangay.codeUnits.fold<int>(
      index * 17,
      (total, code) => total + code,
    );
    final jitterX = ((hash % 17) - 8) / 100;
    final jitterY = (((hash ~/ 17) % 17) - 8) / 100;

    return Offset(
      (x + jitterX).clamp(0.12, 0.88).toDouble(),
      (y + jitterY).clamp(0.18, 0.86).toDouble(),
    );
  }

  Map<String, dynamic> _buildDashboardMetrics(_SuperDashboardData data) {
    final reports = data.reports;
    final offices = data.offices;
    final elevatedUsers = data.users
        .where((user) => ['admin', 'super_admin'].contains(user['role']))
        .toList();
    final resolved = reports
        .where((report) => _reportStatus(report) == 'Resolved')
        .length;
    final unresolved = reports
        .where((report) => _reportStatus(report) != 'Resolved')
        .toList();
    final triggerHours =
        int.tryParse(
          '${data.settings['escalation_settings']?['trigger_time_hours'] ?? 72}',
        ) ??
        72;
    final avgHours = unresolved.isEmpty
        ? 0
        : (unresolved
                      .map((report) {
                        final created = _reportCreatedAt(report);
                        if (created == null) return 0.0;
                        return DateTime.now()
                            .difference(created)
                            .inHours
                            .toDouble();
                      })
                      .fold<double>(0, (sum, value) => sum + value) /
                  unresolved.length)
              .round();
    final resolutionRate = reports.isEmpty
        ? 0
        : ((resolved / reports.length) * 100).round();

    final escalations =
        reports.where((report) {
          final created = _reportCreatedAt(report);
          if (created == null) return false;
          return _reportStatus(report) != 'Resolved' &&
              DateTime.now().difference(created).inHours >= triggerHours;
        }).toList()..sort((a, b) {
          final aDate =
              _reportCreatedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              _reportCreatedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });

    final officeStats =
        offices.map((office) {
            final name = (office['name'] ?? '').toString().trim();
            final officeReports = reports
                .where((report) => _reportOfficeName(report) == name)
                .toList();
            final officeResolved = officeReports
                .where((report) => _reportStatus(report) == 'Resolved')
                .length;
            return {
              'name': name,
              'total': officeReports.length,
              'pending': officeReports
                  .where((report) => _reportStatus(report) == 'Pending')
                  .length,
              'resolved': officeResolved,
              'resolutionRate': officeReports.isEmpty
                  ? 0
                  : ((officeResolved / officeReports.length) * 100).round(),
            };
          }).toList()
          ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    final officePerformance = officeStats.take(5).toList();
    final hottestBarangays = <Map<String, dynamic>>[];
    final byBarangay = <String, int>{};
    for (final report in reports) {
      final barangay = _reportBarangay(report);
      if (barangay.isEmpty) continue;
      byBarangay[barangay] = (byBarangay[barangay] ?? 0) + 1;
    }
    final maxBarangayCount = byBarangay.values.isEmpty
        ? 1
        : byBarangay.values.reduce(math.max);
    final barangayEntries = byBarangay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    hottestBarangays.addAll(
      barangayEntries.asMap().entries.map((entry) {
        final item = entry.value;
        final index = entry.key;
        final ratio = item.value / maxBarangayCount;
        final severity = ratio >= 0.8
            ? 'High'
            : ratio >= 0.45
            ? 'Medium'
            : 'Low';
        final position = _heatMapPositionForBarangay(item.key, index);
        return {
          'label': item.key,
          'count': item.value,
          'severity': severity,
          'share': ((item.value / reports.length.clamp(1, 999999)) * 100)
              .toStringAsFixed(1),
          'x': position.dx,
          'y': position.dy,
        };
      }),
    );
    hottestBarangays.sort(
      (a, b) => (b['count'] as int).compareTo(a['count'] as int),
    );

    final adminRows =
        elevatedUsers.map((user) {
          final department = (user['department'] ?? '').toString().trim();
          return {
            'name': (user['name'] ?? 'Admin User').toString(),
            'department': department.isEmpty ? 'No department' : department,
            'active': user['is_active'] == true,
            'role': (user['role'] ?? 'admin').toString(),
          };
        }).toList()..sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );

    final priorityWeights = {'Low': 1, 'Normal': 2, 'High': 3, 'Urgent': 4};
    final avgSeverity = reports.isEmpty
        ? 0.0
        : reports
                  .map(
                    (report) => priorityWeights[_reportPriority(report)] ?? 2,
                  )
                  .fold<int>(0, (sum, value) => sum + value) /
              reports.length;
    final praiseLike = reports
        .where((report) => _reportStatus(report) == 'Resolved')
        .length;
    final suggestionLike = reports
        .where((report) => _reportStatus(report) == 'Pending')
        .length;
    final complaintLike = reports
        .where(
          (report) =>
              ['In Progress', 'Rejected'].contains(_reportStatus(report)),
        )
        .length;

    final monthlyMap = <int, int>{};
    for (final report in reports) {
      final created = _reportCreatedAt(report);
      if (created == null) continue;
      monthlyMap[created.month] = (monthlyMap[created.month] ?? 0) + 1;
    }
    final monthlySeries = List.generate(
      12,
      (index) => {'month': index + 1, 'count': monthlyMap[index + 1] ?? 0},
    );

    return {
      'totalReports': reports.length,
      'totalDepartments': offices
          .where((office) => office['is_active'] != false)
          .length,
      'avgResponseHours': avgHours,
      'resolutionRate': resolutionRate,
      'escalations': escalations.take(2).toList(),
      'barangays': hottestBarangays.take(5).toList(),
      'officePerformance': officePerformance,
      'officeStats': officeStats.take(6).toList(),
      'adminRows': adminRows.take(4).toList(),
      'feedback': {
        'total': reports.length,
        'avgStars': avgSeverity,
        'praise': praiseLike,
        'suggestion': suggestionLike,
        'complaint': complaintLike,
      },
      'monthlySeries': monthlySeries,
      'escalationTriggerHours': triggerHours,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isDesktop = _isDesktopLayout(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
              title: const Text('Super Admin Dashboard'),
              actions: [
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.backgroundGradient,
          ),
        ),
        child: FutureBuilder<_SuperDashboardData>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData &&
                _cachedDashboardData == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError &&
                !snapshot.hasData &&
                _cachedDashboardData == null) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _GlassMessageCard(
                    title: 'Unable to load command center',
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data ?? _cachedDashboardData;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final currentUser = data.user;
            final metrics = _buildDashboardMetrics(data);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;

                if (isWide) {
                  return Column(
                    children: [
                      _SuperDashboardTopBar(
                        onReportsTap: _openEscalations,
                        onProfileTap: _openSettings,
                        adminName: (currentUser['name'] ?? 'Super Admin')
                            .toString(),
                        isRefreshing: _refreshingDashboard,
                        notificationCount:
                            (metrics['escalations'] as List<dynamic>? ??
                                    const [])
                                .length,
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 220,
                              child: _SuperDashboardSidebar(
                                adminName:
                                    (currentUser['name'] ?? 'Super Admin')
                                        .toString(),
                                selectedSection: _desktopSection,
                                onDashboard: _showDashboard,
                                onReports: _openReports,
                                onAnalytics: _openAnalytics,
                                onFeedback: _openFeedback,
                                onSettings: _openSettings,
                                onUsers: _openUsers,
                                onOffices: _openOffices,
                                onEscalations: _openEscalations,
                                onLogout: _logout,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  24 + bottomSafeArea,
                                ),
                                child: _buildDesktopSection(
                                  bottomSafeArea: bottomSafeArea,
                                  metrics: metrics,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFF2563EB),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24 + bottomSafeArea,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDashboardLanding(metrics: metrics),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardLanding({required Map<String, dynamic> metrics}) {
    final colors = AdminThemeColors.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1180;
    final officePerformance =
        (metrics['officePerformance'] as List<dynamic>? ?? const []);
    final officeStats = (metrics['officeStats'] as List<dynamic>? ?? const []);
    final adminRows = (metrics['adminRows'] as List<dynamic>? ?? const []);
    final escalations = (metrics['escalations'] as List<dynamic>? ?? const []);
    final barangays = (metrics['barangays'] as List<dynamic>? ?? const []);
    final feedback =
        metrics['feedback'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final monthlySeries =
        (metrics['monthlySeries'] as List<dynamic>? ?? const []);
    final subtitle = 'Tacloban City Government - All Offices and Departments';

    return LayoutBuilder(
      builder: (context, constraints) {
        final summaryColumns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final summaryCardWidth =
            (constraints.maxWidth - ((summaryColumns - 1) * 12)) /
            summaryColumns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Overview',
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: colors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashboardStatCard(
                  width: summaryCardWidth,
                  label: 'Total Reports',
                  value: '${metrics['totalReports'] ?? 0}',
                  hint: '+12 this week',
                  color: const Color(0xFF5F92FF),
                ),
                _DashboardStatCard(
                  width: summaryCardWidth,
                  label: 'Total Departments',
                  value: '${metrics['totalDepartments'] ?? 0}',
                  hint: 'Roads, Water, etc.',
                  color: const Color(0xFF8D90A6),
                ),
                _DashboardStatCard(
                  width: summaryCardWidth,
                  label: 'Avg. Response Time',
                  value: '${metrics['avgResponseHours'] ?? 0}h',
                  hint: 'Target < 12h',
                  color: const Color(0xFFF2A84B),
                ),
                _DashboardStatCard(
                  width: summaryCardWidth,
                  label: 'Resolution Rate',
                  value: '${metrics['resolutionRate'] ?? 0}%',
                  hint: '+3% this month',
                  color: const Color(0xFF66D2A3),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _EscalationStrip(
              escalations: escalations.cast<Map<String, dynamic>>(),
              onReportsTap: _openReports,
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _DashboardPanel(
                      title: 'Complaint Heat Map',
                      trailing: 'Tacloban City',
                      child: _HeatMapCard(
                        items: barangays.cast<Map<String, dynamic>>(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _DashboardPanel(
                      title: 'Department Performance',
                      child: _DepartmentPerformanceCard(
                        items: officePerformance.cast<Map<String, dynamic>>(),
                        avgResponseHours:
                            '${metrics['avgResponseHours'] ?? 0}h',
                        resolutionRate: '${metrics['resolutionRate'] ?? 0}%',
                        totalReports: '${metrics['totalReports'] ?? 0}',
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _DashboardPanel(
                title: 'Complaint Heat Map',
                trailing: 'Tacloban City',
                child: _HeatMapCard(
                  items: barangays.cast<Map<String, dynamic>>(),
                ),
              ),
              const SizedBox(height: 16),
              _DashboardPanel(
                title: 'Department Performance',
                child: _DepartmentPerformanceCard(
                  items: officePerformance.cast<Map<String, dynamic>>(),
                  avgResponseHours: '${metrics['avgResponseHours'] ?? 0}h',
                  resolutionRate: '${metrics['resolutionRate'] ?? 0}%',
                  totalReports: '${metrics['totalReports'] ?? 0}',
                ),
              ),
            ],
            const SizedBox(height: 16),
            _DashboardPanel(
              title: 'All Departments',
              trailing: 'Resolution tracking',
              child: _DepartmentGrid(
                items: officeStats.cast<Map<String, dynamic>>(),
              ),
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _DashboardPanel(
                      title: 'Account Management',
                      trailing: 'Create / Disable / Assign',
                      child: _AdminManagementTable(
                        items: adminRows.cast<Map<String, dynamic>>(),
                        onManageTap: _openUsers,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _DashboardPanel(
                      title: 'Feedback Analytics',
                      trailing: 'All departments',
                      child: _FeedbackAnalyticsCard(
                        feedback: feedback,
                        onFeedbackTap: _openFeedback,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _DashboardPanel(
                title: 'Account Management',
                trailing: 'Create / Disable / Assign',
                child: _AdminManagementTable(
                  items: adminRows.cast<Map<String, dynamic>>(),
                  onManageTap: _openUsers,
                ),
              ),
              const SizedBox(height: 16),
              _DashboardPanel(
                title: 'Feedback Analytics',
                trailing: 'All departments',
                child: _FeedbackAnalyticsCard(
                  feedback: feedback,
                  onFeedbackTap: _openFeedback,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _DashboardPanel(
              title: 'Monthly Report Volume - All Departments',
              child: _MonthlyVolumeChart(
                items: monthlySeries.cast<Map<String, dynamic>>(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopSection({
    required double bottomSafeArea,
    required Map<String, dynamic> metrics,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Offstage(
            offstage: _desktopSection != _SuperAdminDesktopSection.dashboard,
            child: TickerMode(
              enabled: _desktopSection == _SuperAdminDesktopSection.dashboard,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24 + bottomSafeArea),
                child: _buildDashboardLanding(metrics: metrics),
              ),
            ),
          ),
        ),
        ..._SuperAdminDesktopSection.values
            .where(
              (section) =>
                  section != _SuperAdminDesktopSection.dashboard &&
                  _loadedDesktopSections.contains(section),
            )
            .map((section) {
              final visible = section == _desktopSection;
              return Positioned.fill(
                child: Offstage(
                  offstage: !visible,
                  child: TickerMode(
                    enabled: visible,
                    child: _buildDesktopSectionContent(section),
                  ),
                ),
              );
            }),
      ],
    );
  }

  Widget _buildDesktopSectionContent(_SuperAdminDesktopSection section) {
    final sectionKey = ValueKey('desktop-${section.name}');

    switch (section) {
      case _SuperAdminDesktopSection.dashboard:
        return const SizedBox.shrink();
      case _SuperAdminDesktopSection.reports:
        return ComplaintManagementScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.analytics:
        return AnalyticsReportsScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.feedback:
        return FeedbackManagementScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.settings:
        return SystemSettingsScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.users:
        return ManageAdminsScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.offices:
        return ManageOfficesScreen(key: sectionKey, embedded: true);
      case _SuperAdminDesktopSection.escalations:
        return EscalationManagementScreen(key: sectionKey, embedded: true);
    }
  }
}

class _SuperDashboardData {
  const _SuperDashboardData({
    required this.user,
    required this.reports,
    required this.users,
    required this.offices,
    required this.settings,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> offices;
  final Map<String, dynamic> settings;
}

class _SuperDashboardTopBar extends StatelessWidget {
  const _SuperDashboardTopBar({
    required this.onReportsTap,
    required this.onProfileTap,
    required this.adminName,
    required this.notificationCount,
    required this.isRefreshing,
  });

  final VoidCallback onReportsTap;
  final VoidCallback onProfileTap;
  final String adminName;
  final int notificationCount;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.topBar,
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(0),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF4C6FFF),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'CityTrack PH',
            style: TextStyle(
              color: colors.isDark ? colors.text : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: colors.warningSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.warningBorder),
            ),
            child: const Text(
              'SUPER ADMIN',
              style: TextStyle(
                color: Color(0xFFF0A43B),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'System Status:',
            style: TextStyle(
              color: colors.isDark
                  ? colors.mutedText
                  : Colors.white.withValues(alpha: 0.88),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isRefreshing
                ? Row(
                    key: const ValueKey('refreshing'),
                    children: const [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Syncing',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Live',
                    key: ValueKey('live'),
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: onReportsTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.isDark
                        ? colors.panelAlt
                        : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.border),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFFFBBF24),
                    size: 17,
                  ),
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notificationCount > 9 ? '9+' : '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? colors.panelAlt
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFFF97316),
                    child: Text(
                      adminName.isEmpty
                          ? 'S'
                          : adminName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    adminName,
                    style: TextStyle(
                      color: colors.isDark ? colors.text : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperDashboardSidebar extends StatelessWidget {
  const _SuperDashboardSidebar({
    required this.adminName,
    required this.selectedSection,
    required this.onDashboard,
    required this.onReports,
    required this.onAnalytics,
    required this.onFeedback,
    required this.onSettings,
    required this.onUsers,
    required this.onOffices,
    required this.onEscalations,
    required this.onLogout,
  });

  final String adminName;
  final _SuperAdminDesktopSection selectedSection;
  final VoidCallback onDashboard;
  final VoidCallback onReports;
  final VoidCallback onAnalytics;
  final VoidCallback onFeedback;
  final VoidCallback onSettings;
  final VoidCallback onUsers;
  final VoidCallback onOffices;
  final VoidCallback onEscalations;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.sidebar,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.sidebarGradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SuperSidebarNavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                isActive:
                    selectedSection == _SuperAdminDesktopSection.dashboard,
                onTap: onDashboard,
              ),
              _SuperSidebarNavItem(
                icon: Icons.apartment_outlined,
                label: 'Departments',
                isActive: selectedSection == _SuperAdminDesktopSection.offices,
                onTap: onOffices,
              ),
              _SuperSidebarNavItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Account Management',
                isActive: selectedSection == _SuperAdminDesktopSection.users,
                onTap: onUsers,
              ),
              _SuperSidebarNavItem(
                icon: Icons.assignment_outlined,
                label: 'All Reports',
                isActive: selectedSection == _SuperAdminDesktopSection.reports,
                onTap: onReports,
              ),
              _SuperSidebarNavItem(
                icon: Icons.insights_outlined,
                label: 'Analytics',
                isActive:
                    selectedSection == _SuperAdminDesktopSection.analytics,
                onTap: onAnalytics,
              ),
              _SuperSidebarNavItem(
                icon: Icons.forum_outlined,
                label: 'Feedback',
                isActive: selectedSection == _SuperAdminDesktopSection.feedback,
                onTap: onFeedback,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 10),
                child: Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: colors.isDark
                        ? colors.mutedText.withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              _SuperSidebarNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isActive: selectedSection == _SuperAdminDesktopSection.settings,
                onTap: onSettings,
              ),
              _SuperSidebarNavItem(
                icon: Icons.notifications_active_outlined,
                label: 'Escalations',
                isActive:
                    selectedSection == _SuperAdminDesktopSection.escalations,
                onTap: onEscalations,
              ),
              _SuperSidebarNavItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                isDestructive: true,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuperSidebarNavItem extends StatelessWidget {
  const _SuperSidebarNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final activeTextColor = colors.activeText;
    const activeIconColor = Colors.white;
    final defaultColor = colors.isDark
        ? colors.mutedText
        : Colors.white.withValues(alpha: 0.88);
    const destructiveColor = Color(0xFFFCA5A5);
    final activeBackground = colors.isDark
        ? colors.activeNav
        : Colors.white.withValues(alpha: 0.20);
    final textColor = isDestructive
        ? destructiveColor
        : (isActive ? activeTextColor : defaultColor);
    final iconColor = isDestructive
        ? destructiveColor
        : (isActive ? activeIconColor : defaultColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeBackground : Colors.transparent,
            border: Border.all(
              color: isActive ? colors.border : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMessageCard extends StatelessWidget {
  const _GlassMessageCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: colors.mutedText, height: 1.4)),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.mutedText, fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(color: colors.mutedText, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EscalationStrip extends StatelessWidget {
  const _EscalationStrip({
    required this.escalations,
    required this.onReportsTap,
  });

  final List<Map<String, dynamic>> escalations;
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    if (escalations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x3311452F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF21593E)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF68D9A2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No reports are currently beyond the escalation window.',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onReportsTap,
              child: const Text('Open Reports'),
            ),
          ],
        ),
      );
    }

    final count = escalations.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x33A12B32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF87353A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.crisis_alert_rounded, color: Color(0xFFFF8E73)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ESCALATION ALERT - $count report${count == 1 ? '' : 's'} have exceeded 72 hours SLA',
                  style: const TextStyle(
                    color: Color(0xFFFF8E73),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...escalations
              .take(2)
              .map(
                (report) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${report['title'] ?? 'Untitled report'} • ${((report['office'] as Map<String, dynamic>?)?['name'] ?? 'No office')}',
                    style: TextStyle(
                      color: colors.isDark
                          ? Colors.white.withValues(alpha: 0.82)
                          : colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeatMapCard extends StatelessWidget {
  const _HeatMapCard({required this.items});

  final List<Map<String, dynamic>> items;

  Color _severityColor(String severity) {
    switch (severity) {
      case 'High':
        return const Color(0xFFE6616D);
      case 'Medium':
        return const Color(0xFFF0B34C);
      default:
        return const Color(0xFF61D69F);
    }
  }

  int _countOf(Map<String, dynamic> item) {
    final value = item['count'];
    return value is num ? value.round() : int.tryParse('$value') ?? 0;
  }

  double _positionOf(Map<String, dynamic> item, String key, double fallback) {
    final value = item[key];
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return (parsed ?? fallback).clamp(0.08, 0.92).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final rankedItems = [...items]
      ..sort((a, b) => _countOf(b).compareTo(_countOf(a)));
    final visibleItems = rankedItems.take(5).toList();
    final maxCount = visibleItems.isEmpty
        ? 1
        : visibleItems.map(_countOf).reduce(math.max).clamp(1, 999999).toInt();
    final totalCount = rankedItems.fold<int>(
      0,
      (sum, item) => sum + _countOf(item),
    );
    final topItem = visibleItems.isEmpty ? null : visibleItems.first;

    if (visibleItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.map_outlined, color: colors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No barangay activity yet',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted complaints will appear here as heat points.',
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth >= 680;
        final map = _HeatMapSurface(
          items: visibleItems,
          maxCount: maxCount,
          severityColorOf: _severityColor,
          countOf: _countOf,
          positionOf: _positionOf,
        );
        final list = Column(
          children: visibleItems
              .map(
                (item) => _HeatMapBarangayRow(
                  item: item,
                  count: _countOf(item),
                  maxCount: maxCount,
                  color: _severityColor((item['severity'] ?? 'Low').toString()),
                ),
              )
              .toList(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeatMapSummaryStrip(
              topItem: topItem,
              totalCount: totalCount,
              hotspotCount: visibleItems.length,
            ),
            const SizedBox(height: 12),
            if (useSplitLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: map),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: list),
                ],
              )
            else ...[
              map,
              const SizedBox(height: 12),
              list,
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: const [
                _MiniLegend(label: 'High complaints', color: Color(0xFFE6616D)),
                _MiniLegend(label: 'Medium', color: Color(0xFFF0B34C)),
                _MiniLegend(label: 'Low', color: Color(0xFF61D69F)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeatMapSurface extends StatelessWidget {
  const _HeatMapSurface({
    required this.items,
    required this.maxCount,
    required this.severityColorOf,
    required this.countOf,
    required this.positionOf,
  });

  final List<Map<String, dynamic>> items;
  final int maxCount;
  final Color Function(String severity) severityColorOf;
  final int Function(Map<String, dynamic> item) countOf;
  final double Function(Map<String, dynamic> item, String key, double fallback)
  positionOf;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeatGridPainter(
                    lineColor: colors.border.withValues(
                      alpha: colors.isDark ? 0.32 : 0.56,
                    ),
                    fillColor: colors.isDark
                        ? Colors.white.withValues(alpha: 0.015)
                        : const Color(0xFFEAF2FC),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: Text(
                  'Tacloban complaint density',
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeatZoneLabel(label: 'Downtown', left: 18, top: 54),
              _HeatZoneLabel(label: 'North', right: 18, top: 54),
              _HeatZoneLabel(label: 'South', right: 18, bottom: 18),
              ...items.asMap().entries.map((entry) {
                final item = entry.value;
                final count = countOf(item);
                final color = severityColorOf(
                  (item['severity'] ?? 'Low').toString(),
                );
                final ratio = (count / maxCount).clamp(0.18, 1.0).toDouble();
                final size = 42 + (ratio * 36);
                final x = positionOf(item, 'x', 0.2 + (entry.key % 3) * 0.24);
                final y = positionOf(item, 'y', 0.28 + (entry.key % 2) * 0.24);
                final left = (constraints.maxWidth * x - (size / 2))
                    .clamp(
                      14.0,
                      math.max(14.0, constraints.maxWidth - size - 14),
                    )
                    .toDouble();
                final top = (constraints.maxHeight * y - (size / 2))
                    .clamp(
                      44.0,
                      math.max(44.0, constraints.maxHeight - size - 14),
                    )
                    .toDouble();

                return Positioned(
                  left: left,
                  top: top,
                  child: Tooltip(
                    message: '${item['label'] ?? 'Barangay'}: $count reports',
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                          alpha: colors.isDark ? 0.18 : 0.16,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.20),
                            blurRadius: 22,
                            spreadRadius: 4,
                          ),
                        ],
                        border: Border.all(
                          color: color.withValues(alpha: 0.88),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: size * 0.58,
                        height: size * 0.58,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _HeatMapSummaryStrip extends StatelessWidget {
  const _HeatMapSummaryStrip({
    required this.topItem,
    required this.totalCount,
    required this.hotspotCount,
  });

  final Map<String, dynamic>? topItem;
  final int totalCount;
  final int hotspotCount;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final topLabel = (topItem?['label'] ?? 'No hotspot').toString();
    final topCountRaw = topItem?['count'];
    final topCount = topCountRaw is num
        ? topCountRaw.round()
        : int.tryParse('$topCountRaw') ?? 0;
    final share = (topItem?['share'] ?? '0.0').toString();

    Widget metric({
      required IconData icon,
      required String label,
      required String value,
      required Color accent,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metric(
                icon: Icons.local_fire_department_outlined,
                label: 'Top barangay',
                value: topLabel,
                accent: const Color(0xFFE6616D),
              ),
              const SizedBox(height: 8),
              metric(
                icon: Icons.bar_chart_rounded,
                label: '$share% of reports',
                value: '$topCount reports',
                accent: const Color(0xFFF0B34C),
              ),
              const SizedBox(height: 8),
              metric(
                icon: Icons.location_on_outlined,
                label: 'Reports mapped',
                value: '$totalCount reports',
                accent: const Color(0xFF5F92FF),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: metric(
                icon: Icons.local_fire_department_outlined,
                label: 'Top barangay',
                value: topLabel,
                accent: const Color(0xFFE6616D),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: metric(
                icon: Icons.bar_chart_rounded,
                label: '$share% of reports',
                value: '$topCount reports',
                accent: const Color(0xFFF0B34C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: metric(
                icon: Icons.location_on_outlined,
                label: '$hotspotCount hotspots shown',
                value: '$totalCount reports',
                accent: const Color(0xFF5F92FF),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeatZoneLabel extends StatelessWidget {
  const _HeatZoneLabel({
    required this.label,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final String label;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.panel.withValues(alpha: colors.isDark ? 0.18 : 0.70),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border.withValues(alpha: 0.65)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HeatGridPainter extends CustomPainter {
  const _HeatGridPainter({required this.lineColor, required this.fillColor});

  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final fillPaint = Paint()..color = fillColor;

    for (var row = 0; row < 4; row += 1) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 48 + (row * 44), size.width - 32, 30),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect, fillPaint);
    }

    for (var column = 1; column < 4; column += 1) {
      final x = size.width * (column / 4);
      canvas.drawLine(Offset(x, 42), Offset(x, size.height - 16), linePaint);
    }
    for (var row = 1; row < 4; row += 1) {
      final y = 42 + ((size.height - 58) * (row / 4));
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _HeatMapBarangayRow extends StatelessWidget {
  const _HeatMapBarangayRow({
    required this.item,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final Map<String, dynamic> item;
  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final ratio = (count / maxCount).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (item['label'] ?? 'Barangay').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: colors.isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE1EAF7),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentPerformanceCard extends StatelessWidget {
  const _DepartmentPerformanceCard({
    required this.items,
    required this.avgResponseHours,
    required this.resolutionRate,
    required this.totalReports,
  });

  final List<Map<String, dynamic>> items;
  final String avgResponseHours;
  final String resolutionRate;
  final String totalReports;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      children: [
        ...items.take(5).map((item) {
          final rate = (item['resolutionRate'] as int?) ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (item['name'] ?? 'Department').toString(),
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        color: rate >= 70
                            ? const Color(0xFF68D9A2)
                            : const Color(0xFFFF9E66),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 8,
                    backgroundColor: colors.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE3ECF8),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 70
                          ? const Color(0xFF68D9A2)
                          : const Color(0xFF5F92FF),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            _InfoTile(label: 'Avg Response Time', value: avgResponseHours),
            _InfoTile(label: 'Resolution Rate', value: resolutionRate),
            _InfoTile(label: 'Total Reports', value: totalReports),
          ],
        ),
      ],
    );
  }
}

class _DepartmentGrid extends StatelessWidget {
  const _DepartmentGrid({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            final rate = (item['resolutionRate'] as int?) ?? 0;
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.panelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['name'] ?? 'Department').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 6,
                      backgroundColor: colors.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE3ECF8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF61D69F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${item['total'] ?? 0} total | ${item['pending'] ?? 0} pending | $rate% resolved',
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AdminManagementTable extends StatelessWidget {
  const _AdminManagementTable({required this.items, required this.onManageTap});

  final List<Map<String, dynamic>> items;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: onManageTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4C6FFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('+ Create Admin'),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              _TableLabel('ADMIN', flex: 4),
              _TableLabel('DEPARTMENT', flex: 4),
              _TableLabel('STATUS', flex: 2),
              _TableLabel('ACTIONS', flex: 3),
            ],
          ),
        ),
        ...items.map(
          (item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF3F4FB8),
                        child: Text(
                          ((item['name'] ?? 'A').toString())
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (item['name'] ?? 'Admin').toString(),
                          style: TextStyle(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    (item['department'] ?? '-').toString(),
                    style: TextStyle(color: colors.mutedText),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _StatusBadge(
                    label: item['active'] == true ? 'Active' : 'Disabled',
                    color: item['active'] == true
                        ? const Color(0xFF68D9A2)
                        : const Color(0xFFE6616D),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _ActionSmallButton(
                        label: 'Edit',
                        color: const Color(0xFF4C6FFF),
                        onTap: onManageTap,
                      ),
                      const SizedBox(width: 8),
                      _ActionSmallButton(
                        label: item['active'] == true ? 'Disable' : 'Enable',
                        color: item['active'] == true
                            ? const Color(0xFFE6616D)
                            : const Color(0xFF68D9A2),
                        onTap: onManageTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackAnalyticsCard extends StatelessWidget {
  const _FeedbackAnalyticsCard({
    required this.feedback,
    required this.onFeedbackTap,
  });

  final Map<String, dynamic> feedback;
  final VoidCallback onFeedbackTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final total = (feedback['total'] ?? 0).toString();
    final avgStars = ((feedback['avgStars'] ?? 0.0) as num).toDouble();
    final praise = (feedback['praise'] ?? 0) as int;
    final suggestion = (feedback['suggestion'] ?? 0) as int;
    final complaint = (feedback['complaint'] ?? 0) as int;
    final denominator = math.max(1, praise + suggestion + complaint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Total Feedback', value: total),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                label: 'Avg. Signal',
                value: avgStars.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FeedbackBar(
          label: 'Praise',
          value: praise / denominator,
          color: const Color(0xFF68D9A2),
          count: praise,
        ),
        _FeedbackBar(
          label: 'Suggestion',
          value: suggestion / denominator,
          color: const Color(0xFF5F92FF),
          count: suggestion,
        ),
        _FeedbackBar(
          label: 'Complaint',
          value: complaint / denominator,
          color: const Color(0xFFE6616D),
          count: complaint,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Slow response',
                    'Helped citizen',
                    'Poor service',
                    'Role clarity',
                  ]
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.input,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(color: colors.mutedText, fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onFeedbackTap,
            child: const Text('Open feedback'),
          ),
        ),
      ],
    );
  }
}

class _MonthlyVolumeChart extends StatelessWidget {
  const _MonthlyVolumeChart({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final maxCount = items.isEmpty
        ? 1
        : items.map((item) => (item['count'] as int?) ?? 0).reduce(math.max);
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(items.length, (index) {
          final count = (items[index]['count'] as int?) ?? 0;
          final height = maxCount == 0
              ? 12.0
              : math.max(12.0, (count / maxCount) * 120);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4D79E6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[index],
                    style: TextStyle(color: colors.mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  const _MiniLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: colors.mutedText, fontSize: 11)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.mutedText, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TableLabel extends StatelessWidget {
  const _TableLabel(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionSmallButton extends StatelessWidget {
  const _ActionSmallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FeedbackBar extends StatelessWidget {
  const _FeedbackBar({
    required this.label,
    required this.value,
    required this.color,
    required this.count,
  });

  final String label;
  final double value;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: colors.text)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
