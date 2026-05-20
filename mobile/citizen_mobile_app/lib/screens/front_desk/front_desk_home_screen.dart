import 'package:flutter/material.dart';

import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/citizen_avatar_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_avatar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/theme_mode_toggle.dart';
import '../citizen/complaint_detail_screen.dart';
import 'front_desk_claim_slip_screen.dart';
import 'front_desk_walk_in_screen.dart';

class FrontDeskHomeScreen extends StatefulWidget {
  const FrontDeskHomeScreen({super.key});

  @override
  State<FrontDeskHomeScreen> createState() => _FrontDeskHomeScreenState();
}

class _FrontDeskHomeScreenState extends State<FrontDeskHomeScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final TextEditingController _searchController = TextEditingController();

  late Future<_FrontDeskWorkspaceData> _workspaceFuture;
  Map<String, dynamic> _currentUser = const {};
  int _selectedTab = 0;
  String _statusFilter = 'All';
  bool _isLoggingOut = false;

  static const List<String> _statusFilters = <String>[
    'All',
    'Submitted',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _workspaceFuture = _loadWorkspace();
  }

  Future<_FrontDeskWorkspaceData> _loadWorkspace() async {
    final results = await Future.wait<dynamic>([
      _authService.getCurrentUser(),
      _dashboardService.getDashboardStats(),
      _reportService.getReports(),
    ]);

    final user = Map<String, dynamic>.from(results[0] as Map);
    _currentUser = user;
    CitizenAvatarService.syncFromUser(user);

    final reports = CitizenReportModel.normalizeReportList(
      (results[2] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(CitizenReportModel.isWalkInOf)
          .toList(),
    );

    return _FrontDeskWorkspaceData(
      user: user,
      dashboard: Map<String, dynamic>.from(results[1] as Map),
      reports: reports,
    );
  }

  Future<void> _refresh() async {
    final future = _loadWorkspace();
    setState(() => _workspaceFuture = future);
    await future;
  }

  Future<void> _openNewWalkInComplaint() async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const FrontDeskWalkInScreen()),
    );

    if (!mounted || created == null) {
      return;
    }

    await _refresh();
    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrontDeskClaimSlipScreen(
          report: CitizenReportModel.normalizeReport(created),
          frontDeskUser: _currentUser,
        ),
      ),
    );

    if (mounted) {
      setState(() => _selectedTab = 1);
    }
  }

  Future<void> _openSlip(Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrontDeskClaimSlipScreen(
          report: CitizenReportModel.normalizeReport(report),
          frontDeskUser: _currentUser,
        ),
      ),
    );
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    final reportId = CitizenReportModel.reportIdOf(report);
    if (reportId == null) {
      await _openSlip(report);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailScreen(reportId: reportId),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
    } catch (_) {
      // Local logout still continues below.
    }

    CitizenDataCache.clear();
    await CitizenAvatarService.clearAvatar();

    if (!mounted) {
      return;
    }

    setState(() => _isLoggingOut = false);
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> reports) {
    final query = _searchController.text.trim().toLowerCase();

    return reports.where((report) {
      if (_statusFilter != 'All' &&
          CitizenReportModel.displayStatusOf(report) != _statusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        CitizenReportModel.referenceNumberOf(report),
        CitizenReportModel.titleOf(report),
        CitizenReportModel.categoryNameOf(report),
        CitizenReportModel.officeNameOf(report),
        CitizenReportModel.complainantNameOf(report),
        CitizenReportModel.complainantContactNumberOf(report),
        CitizenReportModel.displayStatusOf(report),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  int _pendingFollowUps(List<Map<String, dynamic>> reports) {
    return reports
        .where(
          (report) =>
              CitizenReportModel.displayStatusOf(report) != 'Resolved' &&
              CitizenReportModel.expectedReturnAtOf(report) != null,
        )
        .length;
  }

  int _resolvedReports(List<Map<String, dynamic>> reports) {
    return reports
        .where(
          (report) => CitizenReportModel.displayStatusOf(report) == 'Resolved',
        )
        .length;
  }

  String _prettyRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'front_desk' || normalized == 'administrative_staff') {
      return 'Administrative Staff';
    }

    return normalized
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        title: const Text('Administrative Staff Workspace'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: ThemeModeToggle(compact: true)),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: citizenPageGradient(context)),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<_FrontDeskWorkspaceData>(
              future: _workspaceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is AuthSessionExpiredException) {
                    _redirectToLogin();
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 52,
                        color: citizenHighlightColor(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error.toString().replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: citizenBodyColor(context),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      CitizenPrimaryButton(label: 'Retry', onPressed: _refresh),
                    ],
                  );
                }

                final payload = snapshot.data!;
                final reports = _applyFilters(payload.reports);

                Widget content;
                switch (_selectedTab) {
                  case 1:
                    content = _buildReportsTab(reports);
                    break;
                  case 2:
                    content = _buildProfileTab(payload.user);
                    break;
                  case 0:
                  default:
                    content = _buildHomeTab(payload);
                    break;
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: content,
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(_FrontDeskWorkspaceData payload) {
    final reports = payload.reports;

    return ListView(
      key: const ValueKey<String>('front-desk-home'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: citizenHeroGradient(context),
            borderRadius: BorderRadius.circular(26),
            boxShadow: citizenCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Administrative Staff Account',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Assist walk-in citizens with a secure complaint intake.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.98),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Submitted walk-in complaints stay visible only to the administrative staff account that assisted them, their assigned department admins, and super admins.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = 1);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CitizenAppPalette.navy,
                  ),
                  icon: const Icon(Icons.folder_copy_outlined),
                  label: const Text('Open Reports Workspace'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Assisted Reports',
                value: reports.length.toString(),
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Pending Follow-up',
                value: _pendingFollowUps(reports).toString(),
                icon: Icons.event_repeat_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Resolved',
                value: _resolvedReports(reports).toString(),
                icon: Icons.verified_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Recent Assisted Complaints',
          subtitle: reports.isEmpty
              ? 'No walk-in complaints submitted yet.'
              : 'Review recent assisted complaints before moving to the Reports workspace.',
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          _buildEmptyState(
            title: 'No assisted complaints yet',
            subtitle:
                'Open the Reports workspace to record the first walk-in complaint.',
          )
        else
          ...reports.take(4).map(_buildReportCard),
      ],
    );
  }

  Widget _buildReportsTab(List<Map<String, dynamic>> reports) {
    return ListView(
      key: const ValueKey<String>('front-desk-reports'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: citizenBorderColor(context)),
            boxShadow: citizenCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports Workspace',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create new assisted complaints here, then monitor status, follow-up dates, and printable claim slips from the same workspace.',
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 12.8,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openNewWalkInComplaint,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('New Assisted Complaint'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Assisted Complaint Reports',
          subtitle:
              'Search by reference number, complainant, title, category, or status.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search complaints',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusFilters.map((status) {
              final selected = _statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(status),
                  onSelected: (_) {
                    setState(() => _statusFilter = status);
                  },
                  selectedColor: citizenInfoSurfaceColor(context),
                  side: BorderSide(color: citizenBorderColor(context)),
                  labelStyle: TextStyle(
                    color: selected
                        ? citizenTitleColor(context)
                        : citizenBodyColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          _buildEmptyState(
            title: 'No matching complaints',
            subtitle:
                'Try a different status or search keyword, or create a new assisted complaint above.',
          )
        else
          ...reports.map(_buildReportCard),
      ],
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'Administrative Staff').toString();
    final email = (user['email'] ?? 'No email').toString();
    final department = (user['department'] ?? 'Assigned department').toString();
    final role = _prettyRole(
      (user['role'] ?? 'administrative_staff').toString(),
    );
    final jobTitle = (user['job_title'] ?? 'Administrative Staff').toString();

    return ListView(
      key: const ValueKey<String>('front-desk-profile'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: citizenBorderColor(context)),
            boxShadow: citizenCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CitizenAvatar(
                name: name,
                size: 56,
                backgroundColor: citizenInfoSurfaceColor(context),
                textColor: citizenTitleColor(context),
                borderColor: citizenBorderColor(context),
                borderWidth: 1.2,
                fontSize: 22,
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$role | $jobTitle',
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _ProfileLine(label: 'Email', value: email),
              _ProfileLine(label: 'Department', value: department),
              _ProfileLine(
                label: 'Role Access',
                value: 'Walk-in complaint assistance',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: citizenBorderColor(context)),
            boxShadow: citizenCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Display & Session',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Use the theme toggle below to switch your assisted-intake workspace appearance.',
                      style: TextStyle(
                        color: citizenBodyColor(context),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const ThemeModeToggle(),
                ],
              ),
              const SizedBox(height: 18),
              CitizenSecondaryButton(
                label: 'Log Out',
                icon: Icons.logout_rounded,
                onPressed: _isLoggingOut ? null : _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final title = CitizenReportModel.titleOf(report);
    final reference = CitizenReportModel.referenceNumberOf(report);
    final complainant = CitizenReportModel.complainantNameOf(report);
    final category = CitizenReportModel.categoryNameOf(report);
    final office = CitizenReportModel.officeNameOf(report);
    final status = CitizenReportModel.displayStatusOf(report);
    final expectedReturn = CitizenReportModel.expectedReturnAtOf(report);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: citizenBorderColor(context)),
        boxShadow: citizenCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: citizenPriorityFillColor(context, 'Normal'),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: citizenReportStatusColor(
                      context,
                      status,
                    ).withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: citizenReportStatusColor(context, status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$complainant - $category',
            style: TextStyle(color: citizenBodyColor(context), height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '$office - Return: ${expectedReturn == null ? 'To be confirmed' : CitizenReportModel.formatDateTime(expectedReturn)}',
            style: TextStyle(color: citizenBodyColor(context), height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openReportDetail(report),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View Details'),
              ),
              FilledButton.icon(
                onPressed: () => _openSlip(report),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Claim Slip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 42,
            color: citizenMutedColor(context),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: citizenBodyColor(context), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FrontDeskWorkspaceData {
  const _FrontDeskWorkspaceData({
    required this.user,
    required this.dashboard,
    required this.reports,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> reports;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: citizenBorderColor(context)),
        boxShadow: citizenCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: citizenHighlightColor(context)),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: citizenBodyColor(context),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: citizenTitleColor(context),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: citizenBodyColor(context),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: citizenMutedColor(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
