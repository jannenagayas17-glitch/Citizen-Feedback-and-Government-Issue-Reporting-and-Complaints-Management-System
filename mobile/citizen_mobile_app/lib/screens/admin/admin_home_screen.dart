import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../citizen/complaint_detail_screen.dart';
import '../super_admin/manage_admins_screen.dart';
import 'admin_profile_screen.dart';
import 'complaint_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();

  late Future<_AdminHomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
  }

  Future<_AdminHomeData> _loadHome() async {
    final results = await Future.wait([
      _dashboardService.getDashboardStats(),
      _reportService.getAdminReports(),
    ]);

    return _AdminHomeData(
      stats: results[0] as Map<String, dynamic>,
      reports: results[1] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    final future = _loadHome();
    setState(() {
      _homeFuture = future;
    });
    await future;
  }

  Future<void> _openReports() async {
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageAdminsScreen()),
    );
    await _refresh();
  }

  Future<void> _openProfile() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
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
            manageUsersSubtitle: 'Manage citizen and staff account access',
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

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Admin Dashboard'),
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
            colors: [Color(0xFF0C1727), Color(0xFF1A2940), Color(0xFF463327)],
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

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomSafeArea),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _AdminHeroCard(
                    totalReports: '${data.stats['total_reports'] ?? 0}',
                    pending: '${data.stats['pending'] ?? 0}',
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth > 520
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminHomeData {
  const _AdminHomeData({required this.stats, required this.reports});

  final Map<String, dynamic> stats;
  final List<dynamic> reports;
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
                    color: Colors.white.withValues(alpha: 0.72),
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
  const _SectionTitle({required this.title, required this.subtitle});

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
            color: Colors.white.withValues(alpha: 0.70),
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
                color: Colors.white.withValues(alpha: 0.72),
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                          color: Colors.white.withValues(alpha: 0.72),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
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
              color: Colors.white.withValues(alpha: 0.82),
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
