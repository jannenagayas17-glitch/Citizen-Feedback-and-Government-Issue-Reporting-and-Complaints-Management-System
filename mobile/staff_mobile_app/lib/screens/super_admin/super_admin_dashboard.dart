import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../admin/analytics_reports_screen.dart';
import '../auth/login_screen.dart';
import '../admin/complaint_management_screen.dart';
import '../admin/admin_profile_screen.dart';
import 'manage_admins_screen.dart';
import 'manage_offices_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

enum _SuperAdminDesktopSection {
  dashboard,
  reports,
  analytics,
  users,
  offices,
  profile,
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

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
      _dashboardService.getDashboardStats(),
      _authService.getCurrentUser(),
    ]);
    final stats = Map<String, dynamic>.from(results[0] as Map);
    final user = Map<String, dynamic>.from(results[1] as Map);

    return _SuperDashboardData(
      stats: stats,
      user: user,
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

  Future<void> _openProfile() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      if (_isDesktopLayout(context)) {
        setState(() {
          _desktopSection = _SuperAdminDesktopSection.profile;
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
            manageUsersLabel: 'Manage admin users',
            manageUsersSubtitle:
                'Review pending admins and protect elevated access',
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
                  onPressed: _openProfile,
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
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
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
              final stats = data.stats;
              final currentUser = data.user;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;

                  final overview = [
                    const _SuperHeroCard(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final cardWidth = cardConstraints.maxWidth > 520
                            ? (cardConstraints.maxWidth - 12) / 2
                            : cardConstraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricCard(
                              width: cardWidth,
                              icon: Icons.assignment_outlined,
                              label: 'Total Reports',
                              value: '${stats['total_reports'] ?? 0}',
                              color: const Color(0xFF60A5FA),
                            ),
                            _MetricCard(
                              width: cardWidth,
                              icon: Icons.fiber_new_rounded,
                              label: 'New',
                              value: '${stats['new'] ?? 0}',
                              color: const Color(0xFF94A3B8),
                            ),
                            _MetricCard(
                              width: cardWidth,
                              icon: Icons.hourglass_top_rounded,
                              label: 'Pending',
                              value: '${stats['pending'] ?? 0}',
                              color: const Color(0xFFF59E0B),
                            ),
                            _MetricCard(
                              width: cardWidth,
                              icon: Icons.construction_rounded,
                              label: 'In Progress',
                              value: '${stats['in_progress'] ?? 0}',
                              color: const Color(0xFF8B5CF6),
                            ),
                            _MetricCard(
                              width: cardWidth,
                              icon: Icons.verified_rounded,
                              label: 'Resolved',
                              value: '${stats['resolved'] ?? 0}',
                              color: const Color(0xFF22C55E),
                            ),
                          ],
                        );
                      },
                    ),
                  ];

                  final actions = [
                    const _SectionTitle(
                      title: 'Command Actions',
                      subtitle:
                          'Oversee system-wide report handling and administrator access from one place.',
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.analytics_outlined,
                      title: 'Monitor All Reports',
                      subtitle:
                          'Review infrastructure complaints and keep status movement visible across the office.',
                      buttonLabel: 'Open Reports',
                      onTap: _openReports,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.insights_outlined,
                      title: 'Analytics & Exports',
                      subtitle:
                          'Open the reporting dashboard and download an Excel-ready export for leadership reviews.',
                      buttonLabel: 'Open Analytics',
                      onTap: _openAnalytics,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.apartment_outlined,
                      title: 'Manage Offices',
                      subtitle:
                          'Add Tacloban City departments or offices so citizens can route complaints correctly.',
                      buttonLabel: 'Open Office Directory',
                      onTap: _openOffices,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Manage Admin Users',
                      subtitle:
                          'Verify pending accounts, maintain elevated access, and protect admin controls.',
                      buttonLabel: 'Open User Management',
                      onTap: _openUsers,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle:
                          'View your super admin account details and sign out from one place.',
                      buttonLabel: 'Open Profile',
                      onTap: _openProfile,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 250,
                          child: _SuperDashboardSidebar(
                            adminName:
                                (currentUser['name'] ?? 'Super Admin')
                                    .toString(),
                            selectedSection: _desktopSection,
                            onDashboard: _showDashboard,
                            onReports: _openReports,
                            onAnalytics: _openAnalytics,
                            onUsers: _openUsers,
                            onOffices: _openOffices,
                            onProfile: _openProfile,
                            onLogout: _logout,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              12,
                              14,
                              24 + bottomSafeArea,
                            ),
                            child: _buildDesktopSection(
                              bottomSafeArea: bottomSafeArea,
                              overview: overview,
                              actions: actions,
                              currentUser: currentUser,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
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
                              ...overview,
                              const SizedBox(height: 22),
                              ...actions,
                            ],
                          ),
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
    required List<Widget> overview,
    required List<Widget> actions,
    required Map<String, dynamic> currentUser,
  }) {
    switch (_desktopSection) {
      case _SuperAdminDesktopSection.dashboard:
        return ListView(
          padding: EdgeInsets.only(bottom: 24 + bottomSafeArea),
          children: [
            _SuperDashboardTopBar(
              onMenuTap: _showDashboard,
              onReportsTap: _openReports,
              onAnalyticsTap: _openAnalytics,
              onProfileTap: _openProfile,
            ),
            const SizedBox(height: 18),
            const _SuperBreadcrumbCard(
              title: 'Dashboard / System Command Center',
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: overview,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: actions,
                  ),
                ),
              ],
            ),
          ],
        );
      case _SuperAdminDesktopSection.reports:
        return const ComplaintManagementScreen();
      case _SuperAdminDesktopSection.analytics:
        return const AnalyticsReportsScreen();
      case _SuperAdminDesktopSection.users:
        return const ManageAdminsScreen();
      case _SuperAdminDesktopSection.offices:
        return const ManageOfficesScreen();
      case _SuperAdminDesktopSection.profile:
        return AdminProfileScreen(
          user: currentUser,
          onOpenReports: _openReports,
          onOpenUsers: _openUsers,
          manageUsersLabel: 'Manage admin users',
          manageUsersSubtitle:
              'Review pending admins and protect elevated access',
        );
    }
  }
}

class _SuperDashboardData {
  const _SuperDashboardData({
    required this.stats,
    required this.user,
  });

  final Map<String, dynamic> stats;
  final Map<String, dynamic> user;
}

class _SuperDashboardTopBar extends StatelessWidget {
  const _SuperDashboardTopBar({
    required this.onMenuTap,
    required this.onReportsTap,
    required this.onAnalyticsTap,
    required this.onProfileTap,
  });

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
            color: Colors.black.withValues(alpha: 0.05),
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
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search reports, users, or system activity',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  Icon(Icons.search, color: Color(0xFF6B7280)),
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
              child: Icon(Icons.insights_outlined, color: Color(0xFF6B7280)),
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

class _SuperBreadcrumbCard extends StatelessWidget {
  const _SuperBreadcrumbCard({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontWeight: FontWeight.w700,
        ),
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
    required this.onUsers,
    required this.onOffices,
    required this.onProfile,
    required this.onLogout,
  });

  final String adminName;
  final _SuperAdminDesktopSection selectedSection;
  final VoidCallback onDashboard;
  final VoidCallback onReports;
  final VoidCallback onAnalytics;
  final VoidCallback onUsers;
  final VoidCallback onOffices;
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
                          'Super admin access',
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
              _SuperSidebarNavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                isActive: selectedSection == _SuperAdminDesktopSection.dashboard,
                onTap: onDashboard,
              ),
              _SuperSidebarNavItem(
                icon: Icons.assignment_outlined,
                label: 'Reports',
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
                icon: Icons.apartment_outlined,
                label: 'Offices',
                isActive: selectedSection == _SuperAdminDesktopSection.offices,
                onTap: onOffices,
              ),
              _SuperSidebarNavItem(
                icon: Icons.groups_outlined,
                label: 'Users',
                isActive: selectedSection == _SuperAdminDesktopSection.users,
                onTap: onUsers,
              ),
              _SuperSidebarNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isActive: selectedSection == _SuperAdminDesktopSection.profile,
                onTap: onProfile,
              ),
              const Spacer(),
              _SuperSidebarNavItem(
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

class _SuperHeroCard extends StatelessWidget {
  const _SuperHeroCard();

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
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
            Color(0xFF7C3AED),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
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
              const Expanded(
                child: Text(
                  'System Command Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Monitor engineering operations, maintain administrative access, and keep the feedback platform accountable end to end.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              height: 1.4,
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
    required this.color,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
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
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
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
                    color: const Color(0xFF2563EB).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.arrow_outward_rounded,
                    color: Color(0xFFB8D3FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(icon, color: Colors.white.withOpacity(0.82)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              buttonLabel,
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
