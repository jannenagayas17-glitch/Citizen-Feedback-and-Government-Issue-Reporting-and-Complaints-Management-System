import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../utils/admin_theme.dart';
import 'analytics_reports_screen.dart';
import '../auth/login_screen.dart';
import '../super_admin/feedback_management_screen.dart';
import 'admin_profile_screen.dart';
import 'complaint_management_screen.dart';
import 'report_detail_dialog.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _AdminDesktopSection { dashboard, reports, analytics, feedback, profile }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

  late Future<_AdminHomeData> _homeFuture;
  _AdminDesktopSection _desktopSection = _AdminDesktopSection.dashboard;
  String _searchQuery = '';
  String _statusFilter = 'All Status';
  String _priorityFilter = 'All Priority';

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
  }

  Future<_AdminHomeData> _loadHome() async {
    final results = await Future.wait<dynamic>([
      _dashboardService.getDashboardStats(),
      _dashboardService.getAnalytics(),
      _authService.getCurrentUser(),
    ]);

    final stats = Map<String, dynamic>.from(results[0] as Map);
    final analytics = Map<String, dynamic>.from(results[1] as Map);
    final user = Map<String, dynamic>.from(results[2] as Map);

    return _AdminHomeData(
      stats: stats,
      analytics: analytics,
      reports: List<dynamic>.from(
        analytics['recent_reports'] as List<dynamic>? ?? const [],
      ),
      user: user,
    );
  }

  Future<void> _refresh() async {
    final future = _loadHome();
    setState(() {
      _homeFuture = future;
    });
    await future;
  }

  void _showDashboard() {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _AdminDesktopSection.dashboard;
      });
      return;
    }
    _refresh();
  }

  Future<void> _openReports() async {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _AdminDesktopSection.reports;
      });
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ComplaintManagementScreen()),
    );
    await _refresh();
  }

  Future<void> _openReportDetail(int reportId) async {
    await showAdminReportDetailDialog(context: context, reportId: reportId);
    await _refresh();
  }

  Future<void> _openAnalytics() async {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _AdminDesktopSection.analytics;
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
        _desktopSection = _AdminDesktopSection.feedback;
      });
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackManagementScreen()),
    );
    await _refresh();
  }

  Future<void> _openProfile() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      if (_isDesktopLayout(context)) {
        setState(() {
          _desktopSection = _AdminDesktopSection.profile;
        });
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminProfileScreen(
            user: user,
            onOpenReports: () {
              Navigator.pop(context);
              _openReports();
            },
            onOpenUsers: () {
              Navigator.pop(context);
              _openFeedback();
            },
            manageUsersLabel: 'Department feedback',
            manageUsersSubtitle: 'Review feedback assigned to your department',
            showManageUsers: true,
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  bool _isDesktopLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  List<Map<String, dynamic>> _reportMaps(List<dynamic> reports) {
    return reports.whereType<Map<String, dynamic>>().toList();
  }

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) return officeName;
    }

    final department = (user['department'] ?? '').toString().trim();
    if (department.isNotEmpty) return department;

    return 'Department Portal';
  }

  String _reportStatus(Map<String, dynamic> report) {
    final raw = (report['status'] ?? 'Pending').toString().trim();
    if (raw.isEmpty) return 'Pending';
    return raw;
  }

  String _reportPriority(Map<String, dynamic> report) {
    final raw = (report['priority'] ?? 'Normal').toString().trim();
    if (raw.isEmpty) return 'Normal';
    return raw;
  }

  String _reportTitle(Map<String, dynamic> report) {
    return (report['title'] ?? 'Untitled report').toString();
  }

  String _reportLocation(Map<String, dynamic> report) {
    return (report['location'] ?? 'No location').toString();
  }

  String _reportCategory(Map<String, dynamic> report) {
    return (report['category_name'] ?? report['category']?['name'] ?? 'General')
        .toString();
  }

  String _reportCitizen(Map<String, dynamic> report) {
    final user = report['user'];
    if (user is Map<String, dynamic>) {
      final name = (user['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Citizen Reporter';
  }

  int? _reportId(Map<String, dynamic> report) {
    final raw = report['id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return const Color(0xFFEF4444);
      case 'High':
        return const Color(0xFFF97316);
      case 'Low':
        return const Color(0xFF60A5FA);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  InputDecoration _compactFilterDecoration() {
    final colors = AdminThemeColors.of(context);
    return InputDecoration(
      filled: true,
      fillColor: colors.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.primary),
      ),
      hintStyle: TextStyle(color: colors.mutedText),
    );
  }

  List<Map<String, dynamic>> _tableReports(List<Map<String, dynamic>> reports) {
    return reports
        .where((report) {
          final matchesSearch =
              _searchQuery.trim().isEmpty ||
              [
                _reportTitle(report),
                _reportLocation(report),
                _reportCategory(report),
                _reportCitizen(report),
              ].join(' ').toLowerCase().contains(_searchQuery.toLowerCase());

          final matchesStatus =
              _statusFilter == 'All Status' ||
              _reportStatus(report) == _statusFilter;
          final matchesPriority =
              _priorityFilter == 'All Priority' ||
              _reportPriority(report) == _priorityFilter;

          return matchesSearch && matchesStatus && matchesPriority;
        })
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
              title: const Text('Admin Dashboard'),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.backgroundGradient,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: FutureBuilder<_AdminHomeData>(
            future: _homeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _GlassMessageCard(
                      title: 'Unable to load dashboard',
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final reports = data.reports.cast<dynamic>();
              final analytics = data.analytics;
              final currentUser = data.user;
              final queueCount = analytics['queue_count'] is int
                  ? analytics['queue_count'] as int
                  : int.tryParse('${analytics['queue_count']}') ?? 0;
              final statusBreakdown =
                  (analytics['status_breakdown'] as List<dynamic>? ?? const []);
              final priorityBreakdown =
                  (analytics['priority_breakdown'] as List<dynamic>? ??
                  const []);
              final categoryBreakdown =
                  (analytics['category_breakdown'] as List<dynamic>? ??
                  const []);
              final filteredReports = reports.where((item) {
                if (_searchQuery.trim().isEmpty) {
                  return true;
                }
                final report = item as Map<String, dynamic>;
                final user = report['user'] as Map<String, dynamic>?;
                final haystack = [
                  report['title'],
                  report['location'],
                  report['status'],
                  report['category_name'],
                  report['category']?['name'],
                  user?['name'],
                ].whereType<Object>().join(' ').toLowerCase();
                return haystack.contains(_searchQuery.toLowerCase());
              }).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;
                  final content = [
                    _AdminHeroCard(
                      totalReports: '${data.stats['total_reports'] ?? 0}',
                      pending: '${data.stats['pending'] ?? 0}',
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final double width = cardConstraints.maxWidth > 520
                            ? (cardConstraints.maxWidth - 12) / 2
                            : cardConstraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricCard(
                              width: width,
                              icon: Icons.assignment_outlined,
                              label: 'Total Reports',
                              value: '${data.stats['total_reports'] ?? 0}',
                              accent: const Color(0xFF60A5FA),
                            ),
                            _MetricCard(
                              width: width,
                              icon: Icons.hourglass_top_rounded,
                              label: 'Pending',
                              value: '${data.stats['pending'] ?? 0}',
                              accent: const Color(0xFFF59E0B),
                            ),
                            _MetricCard(
                              width: width,
                              icon: Icons.construction_rounded,
                              label: 'In Progress',
                              value: '${data.stats['in_progress'] ?? 0}',
                              accent: const Color(0xFF8B5CF6),
                            ),
                            _MetricCard(
                              width: width,
                              icon: Icons.verified_rounded,
                              label: 'Resolved',
                              value: '${data.stats['resolved'] ?? 0}',
                              accent: const Color(0xFF22C55E),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            title: 'Recent Reports',
                            subtitle:
                                'Latest citizen concerns needing engineering review.',
                          ),
                        ),
                        TextButton(
                          onPressed: _openReports,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (reports.isEmpty)
                      const _GlassMessageCard(
                        title: 'No recent reports',
                        message:
                            'Newly submitted reports will appear here once citizens send them in.',
                      )
                    else
                      ...reports.take(6).map((item) {
                        final report = item as Map<String, dynamic>;
                        final user = report['user'] as Map<String, dynamic>?;
                        final location =
                            (report['location'] ?? 'No location provided')
                                .toString();
                        final category =
                            (report['category_name'] ??
                                    report['category']?['name'] ??
                                    'General')
                                .toString();

                        return _ReportPreviewCard(
                          title: (report['title'] ?? 'Untitled report')
                              .toString(),
                          citizen: (user?['name'] ?? 'Citizen Reporter')
                              .toString(),
                          location: location,
                          category: category,
                          status: (report['status'] ?? 'Pending').toString(),
                          onTap: () => _openReportDetail(report['id'] as int),
                        );
                      }),
                  ];

                  final actions = [
                    const _SectionTitle(
                      title: 'Operations',
                      subtitle: 'Jump into the tools your team uses most.',
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.assignment_turned_in_outlined,
                      iconColor: const Color(0xFFB8D3FF),
                      iconBackground: const Color(0xFF2563EB),
                      title: 'Manage Engineering Reports',
                      subtitle:
                          'Review submitted complaints, update status, and keep field operations moving.',
                      ctaLabel: 'Open Report Queue',
                      onTap: _openReports,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.insights_outlined,
                      iconColor: const Color(0xFFFDE68A),
                      iconBackground: const Color(0xFF7C3AED),
                      title: 'Analytics & Exports',
                      subtitle:
                          'Open the web-style analytics board and download an Excel-ready report file.',
                      ctaLabel: 'Open Analytics',
                      onTap: _openAnalytics,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.rate_review_outlined,
                      iconColor: const Color(0xFFC7F9CC),
                      iconBackground: const Color(0xFF16A34A),
                      title: 'Department Feedback',
                      subtitle:
                          'Review citizen feedback connected to your department.',
                      ctaLabel: 'Open Feedback',
                      onTap: _openFeedback,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFFFFD8B8),
                      iconBackground: const Color(0xFFF97316),
                      title: 'Profile',
                      subtitle:
                          'View your admin account details and sign out from a single place.',
                      ctaLabel: 'Open Profile',
                      onTap: _openProfile,
                    ),
                  ];

                  if (!isWide) {
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        24 + bottomSafeArea,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...content,
                            const SizedBox(height: 22),
                            ...actions,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _DashboardTopBar(
                              onMenuTap: _showDashboard,
                              onReportsTap: _openReports,
                              onProfileTap: _openProfile,
                              departmentName: _departmentLabel(currentUser),
                              adminName: (currentUser['name'] ?? 'Admin User')
                                  .toString(),
                              notificationCount: queueCount,
                            ),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 220,
                                    child: _DashboardSidebar(
                                      selectedSection: _desktopSection,
                                      onDashboard: _showDashboard,
                                      onReports: _openReports,
                                      onAnalytics: _openAnalytics,
                                      onFeedback: _openFeedback,
                                      onProfile: _openProfile,
                                      onLogout: _logout,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDesktopSection(
                                      bottomSafeArea: bottomSafeArea,
                                      data: data,
                                      reports: filteredReports,
                                      statusBreakdown: statusBreakdown,
                                      priorityBreakdown: priorityBreakdown,
                                      categoryBreakdown: categoryBreakdown,
                                      currentUser: currentUser,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSection({
    required double bottomSafeArea,
    required _AdminHomeData data,
    required List<dynamic> reports,
    required List<dynamic> statusBreakdown,
    required List<dynamic> priorityBreakdown,
    required List<dynamic> categoryBreakdown,
    required Map<String, dynamic> currentUser,
  }) {
    switch (_desktopSection) {
      case _AdminDesktopSection.dashboard:
        return _buildDesktopDashboard(
          bottomSafeArea: bottomSafeArea,
          data: data,
          reports: reports,
          statusBreakdown: statusBreakdown,
          priorityBreakdown: priorityBreakdown,
          categoryBreakdown: categoryBreakdown,
          currentUser: currentUser,
        );
      case _AdminDesktopSection.reports:
        return const ComplaintManagementScreen();
      case _AdminDesktopSection.analytics:
        return const AnalyticsReportsScreen(embedded: true);
      case _AdminDesktopSection.feedback:
        return const FeedbackManagementScreen(embedded: true);
      case _AdminDesktopSection.profile:
        return AdminProfileScreen(
          user: currentUser,
          onOpenReports: _openReports,
          onOpenUsers: _openFeedback,
          manageUsersLabel: 'Department feedback',
          manageUsersSubtitle: 'Review feedback assigned to your department',
          showManageUsers: true,
        );
    }
  }

  Widget _buildDesktopDashboard({
    required double bottomSafeArea,
    required _AdminHomeData data,
    required List<dynamic> reports,
    required List<dynamic> statusBreakdown,
    required List<dynamic> priorityBreakdown,
    required List<dynamic> categoryBreakdown,
    required Map<String, dynamic> currentUser,
  }) {
    final reportList = _reportMaps(reports);
    final departmentName = _departmentLabel(currentUser);
    final triageQueue =
        (data.analytics['triage_reports'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final tableReports = _tableReports(reportList);
    final assignedReports = reportList
        .where((report) => _reportStatus(report) == 'In Progress')
        .take(3)
        .toList();
    final staleReports = data.analytics['stale_reports_count'] is int
        ? data.analytics['stale_reports_count'] as int
        : int.tryParse('${data.analytics['stale_reports_count']}') ?? 0;
    final overview = Map<String, dynamic>.from(
      data.analytics['overview'] as Map? ?? const {},
    );
    final rejectedCount = overview['rejected'] is int
        ? overview['rejected'] as int
        : int.tryParse('${overview['rejected']}') ?? 0;
    final colors = AdminThemeColors.of(context);
    final panelGradient = LinearGradient(colors: [colors.panel, colors.panel]);

    return ListView(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 28 + bottomSafeArea),
      children: [
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$departmentName | Tacloban City',
          style: TextStyle(color: colors.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _WideMetricCard(
                title: 'Total Reports',
                value: '${data.stats['total_reports'] ?? 0}',
                subtitle: '${data.stats['queue_count'] ?? 0} active in queue',
                icon: Icons.bar_chart_rounded,
                gradient: panelGradient,
                valueColor: colors.text,
                subtitleColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideMetricCard(
                title: 'Pending',
                value: '${data.stats['pending'] ?? 0}',
                subtitle: 'Needs triage',
                icon: Icons.pending_actions_rounded,
                gradient: panelGradient,
                valueColor: const Color(0xFFFBBF24),
                subtitleColor: colors.mutedText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideMetricCard(
                title: 'In Progress',
                value: '${data.stats['in_progress'] ?? 0}',
                subtitle: '${data.stats['in_progress'] ?? 0} assigned',
                icon: Icons.sync_rounded,
                gradient: panelGradient,
                valueColor: const Color(0xFF60A5FA),
                subtitleColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideMetricCard(
                title: 'Resolved',
                value: '${data.stats['resolved'] ?? 0}',
                subtitle: 'Updated today',
                icon: Icons.check_circle_outline_rounded,
                gradient: panelGradient,
                valueColor: const Color(0xFF22C55E),
                subtitleColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WideMetricCard(
                title: 'Rejected',
                value: '$rejectedCount',
                subtitle: rejectedCount == 0
                    ? 'No rejected reports'
                    : 'Invalid or prank',
                icon: Icons.cancel_outlined,
                gradient: panelGradient,
                valueColor: const Color(0xFFEF4444),
                subtitleColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        if (staleReports > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C171B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7F1D1D)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF87171),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$staleReports reports have exceeded 72 hours without update. Action required immediately.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openReports,
                  child: const Text('View Reports'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _DarkWebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            title: 'Incoming Reports - Triage Queue',
                            subtitle: 'Pending review',
                          ),
                        ),
                        TextButton(
                          onPressed: _openReports,
                          child: const Text('Open queue'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (triageQueue.isEmpty)
                      const _PanelEmptyState(
                        title: 'Queue is clear',
                        subtitle:
                            'No pending or active reports need review right now.',
                      )
                    else
                      ...triageQueue.map((report) {
                        final reportId = _reportId(report);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReportPreviewCard(
                            title: _reportTitle(report),
                            citizen: _reportCitizen(report),
                            location: _reportLocation(report),
                            category: _reportCategory(report),
                            status: _reportStatus(report),
                            onTap: reportId == null
                                ? _openReports
                                : () => _openReportDetail(reportId),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: _DarkWebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            title: 'Assign Staff',
                            subtitle: 'Active field workers',
                          ),
                        ),
                        TextButton(
                          onPressed: _openReports,
                          child: const Text('Open queue'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (assignedReports.isEmpty)
                      const _PanelEmptyState(
                        title: 'No active assignments',
                        subtitle:
                            'Assigned reports will appear here once field work starts.',
                      )
                    else
                      ...assignedReports.map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            tileColor: const Color(0xFF141C2B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _priorityColor(
                                _reportPriority(report),
                              ).withValues(alpha: 0.20),
                              child: Text(
                                _reportCitizen(
                                  report,
                                ).substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: _priorityColor(
                                    _reportPriority(report),
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              _reportCitizen(report),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _reportTitle(report),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                              ),
                            ),
                            trailing: FilledButton(
                              onPressed: _openReports,
                              child: const Text('Open'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DarkWebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      title: 'All Reports',
                      subtitle: 'Filtered working list',
                    ),
                  ),
                  TextButton(
                    onPressed: _openReports,
                    child: const Text('Open full queue'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _searchQuery,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: const TextStyle(color: Colors.white),
                      decoration: _compactFilterDecoration().copyWith(
                        hintText: 'Search reports...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF71809C),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      dropdownColor: const Color(0xFF141C2B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _compactFilterDecoration(),
                      items:
                          const [
                                'All Status',
                                'Pending',
                                'In Progress',
                                'Resolved',
                                'Rejected',
                                'New',
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'All Status'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _priorityFilter,
                      dropdownColor: const Color(0xFF141C2B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _compactFilterDecoration(),
                      items:
                          const [
                                'All Priority',
                                'Low',
                                'Normal',
                                'High',
                                'Urgent',
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(
                        () => _priorityFilter = value ?? 'All Priority',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (tableReports.isEmpty)
                const _PanelEmptyState(
                  title: 'No reports match the current filters',
                  subtitle: 'Try another search, status, or priority.',
                )
              else
                ...tableReports.map((report) {
                  final reportId = _reportId(report);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportPreviewCard(
                      title: _reportTitle(report),
                      citizen: _reportCitizen(report),
                      location: _reportLocation(report),
                      category:
                          '${_reportCategory(report)} | ${_reportPriority(report)}',
                      status: _reportStatus(report),
                      onTap: reportId == null
                          ? _openReports
                          : () => _openReportDetail(reportId),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DarkWebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      title: 'Upload Resolution Proof',
                      subtitle: 'Complete report updates from the queue.',
                    ),
                    const SizedBox(height: 16),
                    const _PanelEmptyState(
                      title: 'Proof uploads are handled in the report queue',
                      subtitle:
                          'Open a report to attach resolution media and mark it resolved.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _openReports,
                      child: const Text('Open Report Queue'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _DarkWebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      title: 'Citizen Feedback',
                      subtitle: 'Latest analytics snapshot',
                    ),
                    const SizedBox(height: 16),
                    if (categoryBreakdown.isEmpty)
                      const _PanelEmptyState(
                        title: 'No feedback data yet',
                        subtitle:
                            'Citizen praise, suggestions, and complaints will appear here.',
                      )
                    else
                      ...categoryBreakdown.take(3).map((item) {
                        final record = item as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            tileColor: const Color(0xFF141C2B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            title: Text(
                              (record['label'] ?? 'Feedback').toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${record['count'] ?? 0} records in analytics',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: _openAnalytics,
                              child: const Text('View'),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminHomeData {
  const _AdminHomeData({
    required this.stats,
    required this.analytics,
    required this.reports,
    required this.user,
  });

  final Map<String, dynamic> stats;
  final Map<String, dynamic> analytics;
  final List<dynamic> reports;
  final Map<String, dynamic> user;
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({required this.totalReports, required this.pending});

  final String totalReports;
  final String pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: const Color(0xFFD8B15A), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Engineering Operations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor report flow, assign follow-up, and keep response times visible.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMiniStat(
                  label: 'Total reports',
                  value: totalReports,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMiniStat(label: 'Awaiting action', value: pending),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: colors.mutedText, height: 1.4)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBackground.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: colors.mutedText),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: colors.mutedText, height: 1.4),
            ),
            const SizedBox(height: 14),
            Text(
              ctaLabel,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPreviewCard extends StatelessWidget {
  const _ReportPreviewCard({
    required this.title,
    required this.citizen,
    required this.location,
    required this.category,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String citizen;
  final String location;
  final String category;
  final String status;
  final VoidCallback onTap;

  Color _statusColor() {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF22C55E);
      case 'In Progress':
        return const Color(0xFF8B5CF6);
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'New':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF60A5FA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final colors = AdminThemeColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.report_problem_outlined,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      const SizedBox(height: 4),
                      Text(citizen, style: TextStyle(color: colors.mutedText)),
                    ],
                  ),
                ),
                _StatusChip(label: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(icon: Icons.category_outlined, label: category),
                _MetaChip(icon: Icons.place_outlined, label: location),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.selectedSection,
    required this.onDashboard,
    required this.onReports,
    required this.onAnalytics,
    required this.onFeedback,
    required this.onProfile,
    required this.onLogout,
  });

  final _AdminDesktopSection selectedSection;
  final VoidCallback onDashboard;
  final VoidCallback onReports;
  final VoidCallback onAnalytics;
  final VoidCallback onFeedback;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      color: colors.sidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SidebarNavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              isActive: selectedSection == _AdminDesktopSection.dashboard,
              onTap: onDashboard,
            ),
            _SidebarNavItem(
              icon: Icons.assignment_outlined,
              label: 'Reports',
              isActive: selectedSection == _AdminDesktopSection.reports,
              onTap: onReports,
            ),
            _SidebarNavItem(
              icon: Icons.insights_outlined,
              label: 'Analytics',
              isActive: selectedSection == _AdminDesktopSection.analytics,
              onTap: onAnalytics,
            ),
            _SidebarNavItem(
              icon: Icons.rate_review_outlined,
              label: 'Feedback',
              isActive: selectedSection == _AdminDesktopSection.feedback,
              onTap: onFeedback,
            ),
            _SidebarNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              isActive: selectedSection == _AdminDesktopSection.profile,
              onTap: onProfile,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 10),
              child: Text(
                'ACCOUNT',
                style: TextStyle(
                  color: colors.mutedText.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            _SidebarNavItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isDestructive: true,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
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
    final activeColor = colors.activeText;
    final defaultColor = colors.isDark ? const Color(0xFFB8C0D4) : Colors.white;
    const destructiveColor = Color(0xFFF87171);
    final itemColor = isDestructive
        ? destructiveColor
        : (isActive ? activeColor : defaultColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? colors.activeNav : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isDestructive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.onMenuTap,
    required this.onReportsTap,
    required this.onProfileTap,
    required this.departmentName,
    required this.adminName,
    required this.notificationCount,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onReportsTap;
  final VoidCallback onProfileTap;
  final String departmentName;
  final String adminName;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.topBar,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'CityTrack PH',
            style: TextStyle(
              color: colors.isDark ? Colors.white : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Admin Portal',
            style: TextStyle(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            departmentName,
            style: TextStyle(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
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
                        ? const Color(0xFF1D2536)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFFFBBF24),
                    size: 18,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0xFF1D2536)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFF8B5CF6),
                    child: Text(
                      adminName.isEmpty
                          ? 'A'
                          : adminName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    adminName,
                    style: TextStyle(
                      color: colors.isDark ? Colors.white : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _WideMetricCard extends StatelessWidget {
  const _WideMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    this.valueColor = Colors.white,
    this.subtitleColor = const Color(0xFF94A3B8),
  });

  final String title;
  final String value;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;
  final Color valueColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              Icon(icon, color: colors.mutedText, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkWebPanel extends StatelessWidget {
  const _DarkWebPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

class _PanelEmptyState extends StatelessWidget {
  const _PanelEmptyState({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final body = subtitle ?? '';
    final colors = AdminThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading != null) ...[
            Text(
              heading,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(body, style: TextStyle(color: colors.mutedText, height: 1.4)),
        ],
      ),
    );
  }
}
