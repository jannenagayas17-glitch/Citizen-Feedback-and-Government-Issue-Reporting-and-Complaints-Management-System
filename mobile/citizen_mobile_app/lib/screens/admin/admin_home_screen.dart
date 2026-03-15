import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/token_storage.dart';
import '../citizen/complaint_detail_screen.dart';
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
    setState(() => _homeFuture = future);
    await future;
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
    } catch (_) {
      await TokenStorage.clearAll();
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AdminHomeData>(
          future: _homeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final reports = data.reports.cast<dynamic>();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF153B9E),
                        Color(0xFF0C2B7A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engineering Office Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track infrastructure complaints, monitor field progress, and respond quickly to city issues.',
                        style: TextStyle(
                          color: Color(0xFFD7E3FF),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Total Reports',
                      value: '${data.stats['total_reports'] ?? 0}',
                      color: const Color(0xFF2E6CF6),
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: '${data.stats['pending'] ?? 0}',
                      color: const Color(0xFFF59E0B),
                    ),
                    _StatCard(
                      label: 'In Progress',
                      value: '${data.stats['in_progress'] ?? 0}',
                      color: const Color(0xFF8B5CF6),
                    ),
                    _StatCard(
                      label: 'Resolved',
                      value: '${data.stats['resolved'] ?? 0}',
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  title: 'View All Reports',
                  subtitle:
                      'Review incoming complaints and update work progress for engineering teams.',
                  icon: Icons.assignment_outlined,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComplaintManagementScreen(),
                      ),
                    );
                    _refresh();
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (reports.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No reports available right now.'),
                    ),
                  )
                else
                  ...reports.take(6).map((item) {
                    final report = item as Map<String, dynamic>;
                    return _ReportPreviewCard(
                      title: (report['title'] ?? 'Untitled report').toString(),
                      subtitle:
                          '${(report['user'] as Map<String, dynamic>?)?['name'] ?? 'Citizen'} - ${(report['status'] ?? 'Pending').toString()}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintDetailScreen(
                              reportId: report['id'] as int,
                            ),
                          ),
                        );
                      },
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminHomeData {
  const _AdminHomeData({
    required this.stats,
    required this.reports,
  });

  final Map<String, dynamic> stats;
  final List<dynamic> reports;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.assignment_outlined, color: Color(0xFF153B9E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ReportPreviewCard extends StatelessWidget {
  const _ReportPreviewCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
