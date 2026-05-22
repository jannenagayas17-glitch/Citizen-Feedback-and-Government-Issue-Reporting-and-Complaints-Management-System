import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/app_routes.dart';
import '../../widgets/portal_shell.dart';
import '../admin/admin_profile_screen.dart';
import '../admin/complaint_management_screen.dart';
import '../admin/report_detail_dialog.dart';
import 'walk_in_claim_slip_dialog.dart';

class AdministrativeStaffHomeScreen extends StatefulWidget {
  const AdministrativeStaffHomeScreen({super.key});

  @override
  State<AdministrativeStaffHomeScreen> createState() =>
      _AdministrativeStaffHomeScreenState();
}

enum _AdministrativeStaffSection { dashboard, reports, profile }

class _AdministrativeStaffHomeScreenState
    extends State<AdministrativeStaffHomeScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();

  late Future<_AdministrativeStaffHomeData> _homeFuture;
  _AdministrativeStaffHomeData? _resolvedHomeData;
  int _requestVersion = 0;
  _AdministrativeStaffSection _desktopSection =
      _AdministrativeStaffSection.dashboard;
  final Set<_AdministrativeStaffSection> _loadedDesktopSections = {
    _AdministrativeStaffSection.dashboard,
  };

  @override
  void initState() {
    super.initState();
    _homeFuture = _queueLoad();
  }

  Future<_AdministrativeStaffHomeData> _queueLoad() {
    final requestId = ++_requestVersion;
    return _loadHome(requestId);
  }

  Future<_AdministrativeStaffHomeData> _loadHome(int requestId) async {
    final results = await Future.wait<dynamic>([
      _authService.getCurrentUser(),
      _dashboardService.getDashboardStats(),
      _reportService.getFrontDeskReportsPage(page: 1, perPage: 6),
    ]);

    final data = _AdministrativeStaffHomeData(
      user: Map<String, dynamic>.from(results[0] as Map),
      stats: Map<String, dynamic>.from(results[1] as Map),
      reportsPage: results[2] as AdminReportPage,
    );

    if (requestId == _requestVersion) {
      _resolvedHomeData = data;
    }

    return data;
  }

  Future<void> _refresh() async {
    final future = _queueLoad();
    setState(() => _homeFuture = future);
    await future;
  }

  bool _isDesktopLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  void _selectDesktopSection(_AdministrativeStaffSection section) {
    if (_desktopSection == section) {
      return;
    }

    _loadedDesktopSections.add(section);
    setState(() => _desktopSection = section);
  }

  void _showDashboard() {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_AdministrativeStaffSection.dashboard);
      return;
    }
    _refresh();
  }

  Future<void> _openReports() async {
    if (_isDesktopLayout(context)) {
      _selectDesktopSection(_AdministrativeStaffSection.reports);
      return;
    }

    final user = _resolvedHomeData?.user ?? await _authService.getCurrentUser();
    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintManagementScreen(
          initialUser: user,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _openProfile() async {
    try {
      if (_isDesktopLayout(context)) {
        _selectDesktopSection(_AdministrativeStaffSection.profile);
        return;
      }

      final user = _resolvedHomeData?.user ?? await _authService.getCurrentUser();
      if (!mounted) {
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
            onOpenUsers: () {},
            showManageUsers: false,
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    final reportId = _reportId(report);
    if (reportId == null) {
      return;
    }

    await showAdminReportDetailDialog(context: context, reportId: reportId);
    await _refresh();
  }

  Future<void> _openClaimSlip(Map<String, dynamic> report) async {
    final user = _resolvedHomeData?.user ?? await _authService.getCurrentUser();
    if (!mounted) {
      return;
    }

    await showWalkInClaimSlipDialog(
      context: context,
      report: report,
      frontDeskUser: user,
    );
  }

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) {
        return officeName;
      }
    }

    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Assigned Department' : department;
  }

  int? _reportId(Map<String, dynamic> report) {
    final raw = report['id'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse('$raw');
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
              title: const Text('Administrative Staff Portal'),
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
          child: FutureBuilder<_AdministrativeStaffHomeData>(
            initialData: _resolvedHomeData,
            future: _homeFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _resolvedHomeData;
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;

              if (isLoading && data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError && data == null) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _StaffMessageCard(
                      title: 'Unable to load portal',
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                    ),
                  ],
                );
              }

              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = data.stats;
              final currentUser = data.user;
              final recentReports = data.reportsPage.reports;
              final queueCount = stats['queue_count'] is int
                  ? stats['queue_count'] as int
                  : int.tryParse('${stats['queue_count']}') ?? 0;

              if (!isDesktop) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomSafeArea),
                  children: _mobileContent(
                    data: data,
                    isLoading: isLoading,
                    currentUser: currentUser,
                    recentReports: recentReports,
                  ),
                );
              }

              return Column(
                children: [
                  PortalTopBar(
                    onLogoTap: _showDashboard,
                    onReportsTap: _openReports,
                    onProfileTap: _openProfile,
                    departmentName: _departmentLabel(currentUser),
                    userName: (currentUser['name'] ?? 'Administrative Staff')
                        .toString(),
                    notificationCount: queueCount,
                    portalLabel: 'Administrative Staff Portal',
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 220,
                          child: PortalSidebar(
                            items: [
                              PortalNavItem(
                                icon: Icons.dashboard_outlined,
                                label: 'Dashboard',
                                isActive:
                                    _desktopSection ==
                                    _AdministrativeStaffSection.dashboard,
                                onTap: _showDashboard,
                              ),
                              PortalNavItem(
                                icon: Icons.assignment_outlined,
                                label: 'All Reports',
                                isActive:
                                    _desktopSection ==
                                    _AdministrativeStaffSection.reports,
                                onTap: _openReports,
                              ),
                              PortalNavItem(
                                icon: Icons.person_outline,
                                label: 'Settings',
                                isActive:
                                    _desktopSection ==
                                    _AdministrativeStaffSection.profile,
                                onTap: _openProfile,
                              ),
                              PortalNavItem(
                                icon: Icons.logout_rounded,
                                label: 'Logout',
                                isDestructive: true,
                                onTap: _logout,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildDesktopSection(
                            bottomSafeArea: bottomSafeArea,
                            data: data,
                            isLoading: isLoading,
                            currentUser: currentUser,
                            recentReports: recentReports,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _mobileContent({
    required _AdministrativeStaffHomeData data,
    required bool isLoading,
    required Map<String, dynamic> currentUser,
    required List<Map<String, dynamic>> recentReports,
  }) {
    return [
      if (isLoading) ...[
        const LinearProgressIndicator(
          minHeight: 3,
          color: Color(0xFF2563EB),
        ),
        const SizedBox(height: 14),
      ],
      _StaffHeroCard(
        name: (currentUser['name'] ?? 'Administrative Staff').toString(),
        department: _departmentLabel(currentUser),
        onOpenReports: _openReports,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StaffStatCard(
            label: 'Assisted Reports',
            value: '${data.stats['total_reports'] ?? 0}',
            icon: Icons.assignment_outlined,
            accent: const Color(0xFF60A5FA),
          ),
          _StaffStatCard(
            label: 'Pending Follow-up',
            value: '${data.stats['pending'] ?? 0}',
            icon: Icons.schedule_outlined,
            accent: const Color(0xFFF59E0B),
          ),
          _StaffStatCard(
            label: 'Resolved',
            value: '${data.stats['resolved'] ?? 0}',
            icon: Icons.verified_outlined,
            accent: const Color(0xFF22C55E),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _StaffSectionCard(
        title: 'Recent Walk-in Complaints',
        subtitle:
            'Complaints assisted through your account appear here and in the shared reports queue.',
        child: recentReports.isEmpty
            ? const _StaffEmptyState(
                title: 'No assisted complaints yet',
                message:
                    'Use All Reports to submit a new walk-in complaint and it will appear here automatically.',
              )
            : Column(
                children: recentReports
                    .map(
                      (report) => _StaffReportPreviewCard(
                        report: report,
                        onView: () => _openReportDetail(report),
                        onSlip: () => _openClaimSlip(report),
                      ),
                    )
                    .toList(),
              ),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _openReports,
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: const Text('Open All Reports'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _openProfile,
        icon: const Icon(Icons.person_outline),
        label: const Text('Open Settings'),
      ),
    ];
  }

  Widget _buildDesktopSection({
    required double bottomSafeArea,
    required _AdministrativeStaffHomeData data,
    required bool isLoading,
    required Map<String, dynamic> currentUser,
    required List<Map<String, dynamic>> recentReports,
  }) {
    final sections = _AdministrativeStaffSection.values;

    return IndexedStack(
      index: _desktopSection.index,
      children: sections.map((section) {
        final shouldBuild =
            section == _AdministrativeStaffSection.dashboard ||
                _loadedDesktopSections.contains(section) ||
                section == _desktopSection;

        if (!shouldBuild) {
          return const SizedBox.shrink();
        }

        return KeyedSubtree(
          key: ValueKey('staff-desktop-${section.name}'),
          child: RepaintBoundary(
            child: switch (section) {
              _AdministrativeStaffSection.dashboard => _buildDesktopDashboard(
                  bottomSafeArea: bottomSafeArea,
                  data: data,
                  isLoading: isLoading,
                  currentUser: currentUser,
                  recentReports: recentReports,
                ),
              _AdministrativeStaffSection.reports => ComplaintManagementScreen(
                  embedded: true,
                  initialUser: currentUser,
                  initialOfficeName: _departmentLabel(currentUser),
                ),
              _AdministrativeStaffSection.profile => AdminProfileScreen(
                  user: currentUser,
                  onOpenReports: _openReports,
                  onOpenUsers: () {},
                  showManageUsers: false,
                ),
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesktopDashboard({
    required double bottomSafeArea,
    required _AdministrativeStaffHomeData data,
    required bool isLoading,
    required Map<String, dynamic> currentUser,
    required List<Map<String, dynamic>> recentReports,
  }) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomSafeArea),
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(
            minHeight: 3,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(height: 14),
        ],
        _StaffHeroCard(
          name: (currentUser['name'] ?? 'Administrative Staff').toString(),
          department: _departmentLabel(currentUser),
          onOpenReports: _openReports,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _StaffStatCard(
              label: 'Assisted Reports',
              value: '${data.stats['total_reports'] ?? 0}',
              icon: Icons.assignment_outlined,
              accent: const Color(0xFF60A5FA),
            ),
            _StaffStatCard(
              label: 'Pending Follow-up',
              value: '${data.stats['pending'] ?? 0}',
              icon: Icons.schedule_outlined,
              accent: const Color(0xFFF59E0B),
            ),
            _StaffStatCard(
              label: 'In Progress',
              value: '${data.stats['in_progress'] ?? 0}',
              icon: Icons.sync_rounded,
              accent: const Color(0xFF8B5CF6),
            ),
            _StaffStatCard(
              label: 'Resolved',
              value: '${data.stats['resolved'] ?? 0}',
              icon: Icons.verified_outlined,
              accent: const Color(0xFF22C55E),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StaffSectionCard(
          title: 'Recent Walk-in Complaints',
          subtitle:
              'Complaints assisted through your account appear here and inside the shared reports workspace.',
          child: recentReports.isEmpty
              ? const _StaffEmptyState(
                  title: 'No assisted complaints yet',
                  message:
                      'Use All Reports to submit a new walk-in complaint and it will appear here automatically.',
                )
              : Column(
                  children: recentReports
                      .map(
                        (report) => _StaffReportPreviewCard(
                          report: report,
                          onView: () => _openReportDetail(report),
                          onSlip: () => _openClaimSlip(report),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _AdministrativeStaffHomeData {
  const _AdministrativeStaffHomeData({
    required this.user,
    required this.stats,
    required this.reportsPage,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> stats;
  final AdminReportPage reportsPage;
}

class _StaffHeroCard extends StatelessWidget {
  const _StaffHeroCard({
    required this.name,
    required this.department,
    required this.onOpenReports,
  });

  final String name;
  final String department;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrative Staff Workspace',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome, $name. Use the shared reports workspace to submit walk-in complaints, monitor follow-ups, and keep assisted concerns inside the same citywide report flow.',
            style: const TextStyle(
              color: Color(0xDDEAF4FF),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StaffPill(label: department),
              const _StaffPill(label: 'Administrative Staff Access'),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenReports,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.primary,
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open All Reports'),
          ),
        ],
      ),
    );
  }
}

class _StaffPill extends StatelessWidget {
  const _StaffPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StaffStatCard extends StatelessWidget {
  const _StaffStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffSectionCard extends StatelessWidget {
  const _StaffSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: colors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StaffReportPreviewCard extends StatelessWidget {
  const _StaffReportPreviewCard({
    required this.report,
    required this.onView,
    required this.onSlip,
  });

  final Map<String, dynamic> report;
  final VoidCallback onView;
  final VoidCallback onSlip;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final complainantName =
        (report['complainant_name'] ??
                report['reporter_name'] ??
                report['user']?['name'] ??
                'Walk-in complainant')
            .toString();
    final category =
        (report['category']?['name'] ?? report['category_name'] ?? 'General')
            .toString();
    final office = (report['office']?['name'] ?? 'Assigned Department')
        .toString();
    final status = (report['status'] ?? 'New').toString();
    final title = (report['title'] ?? 'Walk-in complaint').toString();
    final referenceNumber =
        (report['printable_reference_number'] ?? 'Pending reference')
            .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(16),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _StaffStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$complainantName • $category • $office',
            style: TextStyle(color: colors.mutedText, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            referenceNumber,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onView,
                child: const Text('View Details'),
              ),
              OutlinedButton.icon(
                onPressed: onSlip,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Claim Slip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffStatusBadge extends StatelessWidget {
  const _StaffStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final color = switch (status) {
      'Resolved' => const Color(0xFF22C55E),
      'In Progress' => const Color(0xFF8B5CF6),
      'Rejected' => const Color(0xFFEF4444),
      'Pending' => const Color(0xFFF59E0B),
      _ => const Color(0xFF60A5FA),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StaffMessageCard extends StatelessWidget {
  const _StaffMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StaffEmptyState extends StatelessWidget {
  const _StaffEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_late_outlined,
            color: colors.mutedText,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}
