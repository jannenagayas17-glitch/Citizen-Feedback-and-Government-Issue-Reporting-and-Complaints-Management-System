import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../citizen/complaint_detail_screen.dart';
import 'analytics_reports_screen.dart';
import '../auth/login_screen.dart';
import '../super_admin/manage_admins_screen.dart';
import 'admin_profile_screen.dart';
import 'complaint_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _AdminDesktopSection {
  dashboard,
  reports,
  analytics,
  users,
  profile,
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();

  late Future<_AdminHomeData> _homeFuture;
  _AdminDesktopSection _desktopSection = _AdminDesktopSection.dashboard;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
  }

  Future<_AdminHomeData> _loadHome() async {
    final results = await Future.wait([
      _dashboardService.getDashboardStats(),
      _dashboardService.getAnalytics(),
      _reportService.getAdminReports(),
      _authService.getCurrentUser(),
    ]);

    return _AdminHomeData(
      stats: results[0] as Map<String, dynamic>,
      analytics: results[1] as Map<String, dynamic>,
      reports: results[2] as List<dynamic>,
      user: results[3] as Map<String, dynamic>,
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailScreen(reportId: reportId),
      ),
    );
    await _refresh();
  }

  Future<void> _openUsers() async {
    if (_isDesktopLayout(context)) {
      setState(() {
        _desktopSection = _AdminDesktopSection.users;
      });
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageAdminsScreen()),
    );
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
              _openUsers();
            },
            manageUsersLabel: 'Account directory',
            manageUsersSubtitle:
                'Manage citizen and staff account access',
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

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0C1727),
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Admin Dashboard'),
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
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final reports = data.reports.cast<dynamic>();
              final analytics = data.analytics;
              final currentUser = data.user;
              final statusBreakdown =
                  (analytics['status_breakdown'] as List<dynamic>? ?? const []);
              final priorityBreakdown = (analytics['priority_breakdown']
                      as List<dynamic>? ??
                  const []);
              final categoryBreakdown = (analytics['category_breakdown']
                      as List<dynamic>? ??
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
                          title:
                              (report['title'] ?? 'Untitled report').toString(),
                          citizen:
                              (user?['name'] ?? 'Citizen Reporter').toString(),
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
                      icon: Icons.groups_outlined,
                      iconColor: const Color(0xFFC7F9CC),
                      iconBackground: const Color(0xFF16A34A),
                      title: 'Manage Accounts',
                      subtitle:
                          'Review citizen and staff accounts, and deactivate accounts when needed.',
                      ctaLabel: 'Open Account Directory',
                      onTap: _openUsers,
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
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...content,
                                const SizedBox(height: 22),
                                ...actions,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: _DashboardSidebar(
                          adminName:
                              (currentUser['name'] ?? 'Admin User').toString(),
                          selectedSection: _desktopSection,
                          onDashboard: _showDashboard,
                          onReports: _openReports,
                          onAnalytics: _openAnalytics,
                          onUsers: _openUsers,
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
        );
      case _AdminDesktopSection.reports:
        return const ComplaintManagementScreen();
      case _AdminDesktopSection.analytics:
        return const AnalyticsReportsScreen();
      case _AdminDesktopSection.users:
        return const ManageAdminsScreen();
      case _AdminDesktopSection.profile:
        return AdminProfileScreen(
          user: currentUser,
          onOpenReports: _openReports,
          onOpenUsers: _openUsers,
          manageUsersLabel: 'Account directory',
          manageUsersSubtitle: 'Manage citizen and staff account access',
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
  }) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 24 + bottomSafeArea),
      children: [
        _DashboardTopBar(
          searchQuery: _searchQuery,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onMenuTap: _showDashboard,
          onReportsTap: _openReports,
          onAnalyticsTap: _openAnalytics,
          onProfileTap: _openProfile,
        ),
        const SizedBox(height: 18),
        const _BreadcrumbCard(
          title: 'Dashboard / Engineering Operations',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _WideMetricCard(
              title: 'Total Reports',
              value: '${data.stats['total_reports'] ?? 0}',
              subtitle: 'All infrastructure reports',
              icon: Icons.assignment_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
            ),
            _WideMetricCard(
              title: 'Pending',
              value: '${data.stats['pending'] ?? 0}',
              subtitle: 'Awaiting engineering review',
              icon: Icons.hourglass_top_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
              ),
            ),
            _WideMetricCard(
              title: 'In Progress',
              value: '${data.stats['in_progress'] ?? 0}',
              subtitle: 'Active field coordination',
              icon: Icons.construction_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFDB2777), Color(0xFFEC4899)],
              ),
            ),
            _WideMetricCard(
              title: 'Resolved',
              value: '${data.stats['resolved'] ?? 0}',
              subtitle: 'Closed with completed action',
              icon: Icons.verified_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9D8A), Color(0xFF20B2AA)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DarkWebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      title: 'Overview',
                      subtitle:
                          'See the main analytics snapshot directly from the dashboard.',
                    ),
                  ),
                  TextButton(
                    onPressed: _openAnalytics,
                    child: const Text('Open analytics'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 950) {
                    return Column(
                      children: [
                        _OverviewAnalyticsCard(
                          title: 'Status Overview',
                          child: _BreakdownOverview(
                            title: 'Status Overview',
                            items: statusBreakdown,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _OverviewAnalyticsCard(
                          title: 'Priority Overview',
                          child: _BreakdownOverview(
                            title: 'Priority Overview',
                            items: priorityBreakdown,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _OverviewAnalyticsCard(
                          title: 'Top Categories',
                          child: _BreakdownOverview(
                            title: 'Top Categories',
                            items: categoryBreakdown,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _OverviewAnalyticsCard(
                          title: 'Status Overview',
                          child: _BreakdownOverview(
                            title: 'Status Overview',
                            items: statusBreakdown,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _OverviewAnalyticsCard(
                          title: 'Priority Overview',
                          child: _BreakdownOverview(
                            title: 'Priority Overview',
                            items: priorityBreakdown,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _OverviewAnalyticsCard(
                          title: 'Top Categories',
                          child: _BreakdownOverview(
                            title: 'Top Categories',
                            items: categoryBreakdown,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _DarkWebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    child: const Text('Open full queue'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (reports.isEmpty)
                _PanelEmptyState(
                  title: _searchQuery.trim().isEmpty
                      ? 'No recent reports yet'
                      : 'No reports match your search',
                  subtitle: _searchQuery.trim().isEmpty
                      ? 'New reports submitted by citizens will appear here.'
                      : 'Try a different report title, location, category, or citizen name.',
                )
              else
                ...reports.take(4).map((item) {
                  final report = item as Map<String, dynamic>;
                  final user = report['user'] as Map<String, dynamic>?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReportPreviewCard(
                      title: (report['title'] ?? 'Untitled report').toString(),
                      citizen:
                          (user?['name'] ?? 'Citizen Reporter').toString(),
                      location:
                          (report['location'] ?? 'No location provided')
                              .toString(),
                      category: (report['category_name'] ??
                              report['category']?['name'] ??
                              'General')
                          .toString(),
                      status: (report['status'] ?? 'Pending').toString(),
                      onTap: () => _openReportDetail(report['id'] as int),
                    ),
                  );
                }),
            ],
          ),
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
  const _AdminHeroCard({
    required this.totalReports,
    required this.pending,
  });

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
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
            Color(0xFF0F172A),
          ],
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
                  border: Border.all(
                    color: const Color(0xFFD8B15A),
                    width: 2,
                  ),
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
                        color: Colors.white.withOpacity(0.82),
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
                child: _HeroMiniStat(
                  label: 'Awaiting action',
                  value: pending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
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
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
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
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            height: 1.4,
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              ctaLabel,
              style: const TextStyle(
                color: Color(0xFFB8D3FF),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
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
                    color: statusColor.withOpacity(0.14),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        citizen,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
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
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
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
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFB8D3FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
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
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
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
              color: Colors.white.withOpacity(0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.adminName,
    required this.selectedSection,
    required this.onDashboard,
    required this.onReports,
    required this.onAnalytics,
    required this.onUsers,
    required this.onProfile,
    required this.onLogout,
  });

  final String adminName;
  final _AdminDesktopSection selectedSection;
  final VoidCallback onDashboard;
  final VoidCallback onReports;
  final VoidCallback onAnalytics;
  final VoidCallback onUsers;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3D4458),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'City Engineering Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Admin access',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
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
                icon: Icons.groups_outlined,
                label: 'Users',
                isActive: selectedSection == _AdminDesktopSection.users,
                onTap: onUsers,
              ),
              _SidebarNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isActive: selectedSection == _AdminDesktopSection.profile,
                onTap: onProfile,
              ),
              const Spacer(),
              _SidebarNavItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                isDestructive: true,
                onTap: onLogout,
              ),
              const SizedBox(height: 12),
              Text(
                'City Engineering Portal',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
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
    const activeColor = Color(0xFFFBBF24);
    const defaultColor = Colors.white;
    const destructiveColor = Color(0xFFFCA5A5);
    final itemColor = isDestructive
        ? destructiveColor
        : (isActive ? activeColor : defaultColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFF59E0B).withValues(alpha: 0.24)
                : Colors.transparent,
            border: isActive
                ? Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.60),
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: itemColor,
                size: 18,
              ),
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
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? destructiveColor.withValues(alpha: 0.80)
                    : (isActive
                        ? activeColor.withValues(alpha: 0.90)
                        : defaultColor.withValues(alpha: 0.60)),
                size: 18,
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
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onMenuTap,
    required this.onReportsTap,
    required this.onAnalyticsTap,
    required this.onProfileTap,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMenuTap;
  final VoidCallback onReportsTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: searchQuery,
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search reports, locations, or citizens',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: const TextStyle(color: Color(0xFF334155)),
                    ),
                  ),
                  const Icon(Icons.search, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: onReportsTap,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.assignment_outlined, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            onTap: onAnalyticsTap,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.insights_outlined,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbCard extends StatelessWidget {
  const _BreadcrumbCard({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.90),
          fontWeight: FontWeight.w700,
        ),
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
  });

  final String title;
  final String value;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.35,
                  ),
                ),
              ),
              Icon(icon, color: Colors.white, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkWebPanel extends StatelessWidget {
  const _DarkWebPanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
        ],
      ),
    );
  }
}

class _PanelEmptyState extends StatelessWidget {
  const _PanelEmptyState({
    this.title,
    this.subtitle,
    this.message,
  });

  final String? title;
  final String? subtitle;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final body = message ?? subtitle ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading != null) ...[
            Text(
              heading,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewAnalyticsCard extends StatelessWidget {
  const _OverviewAnalyticsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BreakdownOverview extends StatelessWidget {
  const _BreakdownOverview({
    required this.title,
    required this.items,
  });

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.isEmpty
        ? 1.0
        : items
            .map((item) => ((item as Map<String, dynamic>)['count'] as num?)?.toDouble() ?? 0)
            .fold<double>(1, (maxValue, value) => value > maxValue ? value : maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          const _PanelEmptyState(message: 'No analytics data yet.')
        else
          ...items.take(5).map((item) {
            final record = item as Map<String, dynamic>;
            final count = ((record['count'] ?? 0) as num).toDouble();
            final progress = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (record['label'] ?? 'Unknown').toString(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          count.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
