import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../services/system_settings_service.dart';
import '../admin/analytics_reports_screen.dart';
import '../auth/login_screen.dart';
import '../admin/complaint_management_screen.dart';
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
  _SuperAdminDesktopSection _desktopSection =
      _SuperAdminDesktopSection.dashboard;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadDashboard();
  }

  Future<_SuperDashboardData> _loadDashboard() async {
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

    return _SuperDashboardData(
      user: user,
      reports: reports,
      users: users,
      offices: offices,
      settings: settings,
    );
  }

  Future<void> _refresh() async {
    final future = _loadDashboard();
    setState(() {
      _statsFuture = future;
    });
    await future;
  }

  bool _isDesktopLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  void _showDashboard() {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.dashboard;
      });
      return;
    }
    _refresh();
  }

  Future<void> _openReports() async {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.reports;
      });
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
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.users;
      });
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
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.offices;
      });
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
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.analytics;
      });
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
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.feedback;
      });
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
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.settings;
      });
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SystemSettingsScreen(),
      ),
    );
    await _refresh();
  }

  Future<void> _openEscalations() async {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _SuperAdminDesktopSection.escalations;
      });
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

  Map<String, dynamic> _buildDashboardMetrics(_SuperDashboardData data) {
    final reports = data.reports;
    final offices = data.offices;
    final elevatedUsers = data.users
        .where((user) => ['admin', 'super_admin'].contains(user['role']))
        .toList();
    final resolved =
        reports.where((report) => _reportStatus(report) == 'Resolved').length;
    final unresolved = reports
        .where((report) => _reportStatus(report) != 'Resolved')
        .toList();
    final triggerHours = int.tryParse(
          '${data.settings['escalation_settings']?['trigger_time_hours'] ?? 72}',
        ) ??
        72;
    final avgHours = unresolved.isEmpty
        ? 0
        : (unresolved.map((report) {
              final created = _reportCreatedAt(report);
              if (created == null) return 0.0;
              return DateTime.now().difference(created).inHours.toDouble();
            }).fold<double>(0, (sum, value) => sum + value) /
            unresolved.length)
            .round();
    final resolutionRate =
        reports.isEmpty ? 0 : ((resolved / reports.length) * 100).round();

    final escalations = reports.where((report) {
      final created = _reportCreatedAt(report);
      if (created == null) return false;
      return _reportStatus(report) != 'Resolved' &&
          DateTime.now().difference(created).inHours >= triggerHours;
    }).toList()
      ..sort((a, b) {
        final aDate = _reportCreatedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = _reportCreatedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

    final officeStats = offices.map((office) {
      final name = (office['name'] ?? '').toString().trim();
      final officeReports =
          reports.where((report) => _reportOfficeName(report) == name).toList();
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
    final maxBarangayCount =
        byBarangay.values.isEmpty ? 1 : byBarangay.values.reduce(math.max);
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
        return {
          'label': item.key,
          'count': item.value,
          'severity': severity,
          'x': 0.18 + (index % 4) * 0.2,
          'y': 0.28 + (index % 3) * 0.18,
        };
      }),
    );
    hottestBarangays.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final adminRows = elevatedUsers.map((user) {
      final department = (user['department'] ?? '').toString().trim();
      return {
        'name': (user['name'] ?? 'Admin User').toString(),
        'department': department.isEmpty ? 'No department' : department,
        'active': user['is_active'] == true,
        'role': (user['role'] ?? 'admin').toString(),
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final priorityWeights = {'Low': 1, 'Normal': 2, 'High': 3, 'Urgent': 4};
    final avgSeverity = reports.isEmpty
        ? 0.0
        : reports
                .map((report) => priorityWeights[_reportPriority(report)] ?? 2)
                .fold<int>(0, (sum, value) => sum + value) /
            reports.length;
    final praiseLike = reports.where((report) => _reportStatus(report) == 'Resolved').length;
    final suggestionLike = reports.where((report) => _reportStatus(report) == 'Pending').length;
    final complaintLike = reports
        .where((report) => ['In Progress', 'Rejected'].contains(_reportStatus(report)))
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
      'totalDepartments': offices.where((office) => office['is_active'] != false).length,
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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isDesktop = _isDesktopLayout(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0C1727),
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Super Admin Dashboard'),
              actions: [
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1A2940),
              Color(0xFF463327),
            ],
          ),
        ),
        child: FutureBuilder<_SuperDashboardData>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _GlassMessageCard(
                    title: 'Unable to load command center',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
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
                        adminName:
                            (currentUser['name'] ?? 'Super Admin').toString(),
                        notificationCount:
                            (metrics['escalations'] as List<dynamic>? ?? const [])
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
                              _buildDashboardLanding(
                                metrics: metrics,
                              ),
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

  Widget _buildDashboardLanding({
    required Map<String, dynamic> metrics,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 1180;
    final officePerformance =
        (metrics['officePerformance'] as List<dynamic>? ?? const []);
    final officeStats = (metrics['officeStats'] as List<dynamic>? ?? const []);
    final adminRows = (metrics['adminRows'] as List<dynamic>? ?? const []);
    final escalations = (metrics['escalations'] as List<dynamic>? ?? const []);
    final barangays = (metrics['barangays'] as List<dynamic>? ?? const []);
    final feedback =
        metrics['feedback'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final monthlySeries =
        (metrics['monthlySeries'] as List<dynamic>? ?? const []);
    final subtitle =
        'Tacloban City Engineering Office - All Departments';

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
            const Text(
              'System Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 13,
              ),
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
                      child: _HeatMapCard(items: barangays.cast<Map<String, dynamic>>()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _DashboardPanel(
                      title: 'Department Performance',
                      child: _DepartmentPerformanceCard(
                        items: officePerformance.cast<Map<String, dynamic>>(),
                        avgResponseHours: '${metrics['avgResponseHours'] ?? 0}h',
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
                child: _HeatMapCard(items: barangays.cast<Map<String, dynamic>>()),
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
              child: _DepartmentGrid(items: officeStats.cast<Map<String, dynamic>>()),
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _DashboardPanel(
                      title: 'Admin Management',
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
                title: 'Admin Management',
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
              child: _MonthlyVolumeChart(items: monthlySeries.cast<Map<String, dynamic>>()),
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
    switch (_desktopSection) {
      case _SuperAdminDesktopSection.dashboard:
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24 + bottomSafeArea),
          child: _buildDashboardLanding(
            metrics: metrics,
          ),
        );
      case _SuperAdminDesktopSection.reports:
        return const ComplaintManagementScreen(embedded: true);
      case _SuperAdminDesktopSection.analytics:
        return const AnalyticsReportsScreen(embedded: true);
      case _SuperAdminDesktopSection.feedback:
        return const FeedbackManagementScreen(embedded: true);
      case _SuperAdminDesktopSection.settings:
        return const SystemSettingsScreen(embedded: true);
      case _SuperAdminDesktopSection.users:
        return const ManageAdminsScreen(embedded: true);
      case _SuperAdminDesktopSection.offices:
        return const ManageOfficesScreen(embedded: true);
      case _SuperAdminDesktopSection.escalations:
        return const EscalationManagementScreen(embedded: true);
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
  });

  final VoidCallback onReportsTap;
  final VoidCallback onProfileTap;
  final String adminName;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111625),
        borderRadius: BorderRadius.circular(0),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
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
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'CityTrack PH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2018),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF6F4D2C)),
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
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
                    color: const Color(0xFF171E2D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
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
                color: const Color(0xFF171E2D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
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
                    style: const TextStyle(
                      color: Colors.white,
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
    return Container(
      color: const Color(0xFF101423),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SuperSidebarNavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                isActive: selectedSection == _SuperAdminDesktopSection.dashboard,
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
                label: 'Admin Management',
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
                isActive: selectedSection == _SuperAdminDesktopSection.analytics,
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
                    color: Colors.white.withValues(alpha: 0.34),
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
                isActive: selectedSection == _SuperAdminDesktopSection.escalations,
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
    const activeTextColor = Color(0xFFF0A43B);
    const activeIconColor = Colors.white;
    const defaultColor = Color(0xFFD6DBE7);
    const destructiveColor = Color(0xFFFCA5A5);
    const activeBackground = Color(0xFF243455);
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
            color: isActive
                ? activeBackground
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
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
  const _GlassMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
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
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 11,
                  ),
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
            const Expanded(
              child: Text(
                'No reports are currently beyond the escalation window.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: onReportsTap, child: const Text('Open Reports'))
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
          ...escalations.take(2).map(
            (report) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${report['title'] ?? 'Untitled report'} • ${((report['office'] as Map<String, dynamic>?)?['name'] ?? 'No office')}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF101525),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      4,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.015),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ...items.take(5).map((item) {
                final color = _severityColor((item['severity'] ?? 'Low').toString());
                return Positioned(
                  left: 30 + 240 * ((item['x'] as num?)?.toDouble() ?? 0.2),
                  top: 20 + 120 * ((item['y'] as num?)?.toDouble() ?? 0.2),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.8)),
                    ),
                    child: Text(
                      (item['severity'] ?? 'Low').toString().substring(0, 3).toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: const [
            _MiniLegend(label: 'High complaints', color: Color(0xFFE6616D)),
            _MiniLegend(label: 'Medium', color: Color(0xFFF0B34C)),
            _MiniLegend(label: 'Low', color: Color(0xFF61D69F)),
          ],
        ),
      ],
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        color: rate >= 70 ? const Color(0xFF68D9A2) : const Color(0xFFFF9E66),
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
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 70 ? const Color(0xFF68D9A2) : const Color(0xFF5F92FF),
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
                color: const Color(0xFF111829),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['name'] ?? 'Department').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF61D69F)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${item['total'] ?? 0} total | ${item['pending'] ?? 0} pending | $rate% resolved',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12),
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
  const _AdminManagementTable({
    required this.items,
    required this.onManageTap,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
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
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
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
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
              ),
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
                          ((item['name'] ?? 'A').toString()).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (item['name'] ?? 'Admin').toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    (item['department'] ?? '-').toString(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
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
                      _ActionSmallButton(label: 'Edit', color: const Color(0xFF4C6FFF), onTap: onManageTap),
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
            Expanded(child: _InfoTile(label: 'Total Feedback', value: total)),
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
        _FeedbackBar(label: 'Praise', value: praise / denominator, color: const Color(0xFF68D9A2), count: praise),
        _FeedbackBar(label: 'Suggestion', value: suggestion / denominator, color: const Color(0xFF5F92FF), count: suggestion),
        _FeedbackBar(label: 'Complaint', value: complaint / denominator, color: const Color(0xFFE6616D), count: complaint),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Slow response',
            'Helped citizen',
            'Poor service',
            'Role clarity',
          ]
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111829),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11),
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
    final maxCount = items.isEmpty
        ? 1
        : items
            .map((item) => (item['count'] as int?) ?? 0)
            .reduce(math.max);
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(items.length, (index) {
          final count = (items[index]['count'] as int?) ?? 0;
          final height = maxCount == 0 ? 12.0 : math.max(12.0, (count / maxCount) * 120);
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11)),
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111829),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.46),
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
