import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/token_storage.dart';
import '../admin/complaint_management_screen.dart';
import 'manage_admins_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _dashboardService.getDashboardStats();
  }

  Future<void> _refresh() async {
    final future = _dashboardService.getDashboardStats();
    setState(() => _statsFuture = future);
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
        title: const Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
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

            final stats = snapshot.data ?? const <String, dynamic>{};

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
                        'System Command Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Monitor reports, manage administrators, and oversee city-wide feedback activity.',
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
                      value: '${stats['total_reports'] ?? 0}',
                      color: const Color(0xFF2E6CF6),
                    ),
                    _StatCard(
                      label: 'New',
                      value: '${stats['new'] ?? 0}',
                      color: const Color(0xFF64748B),
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: '${stats['pending'] ?? 0}',
                      color: const Color(0xFFF59E0B),
                    ),
                    _StatCard(
                      label: 'In Progress',
                      value: '${stats['in_progress'] ?? 0}',
                      color: const Color(0xFF8B5CF6),
                    ),
                    _StatCard(
                      label: 'Resolved',
                      value: '${stats['resolved'] ?? 0}',
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
                  title: 'Monitor All Reports',
                  subtitle:
                      'Review infrastructure complaints and status activity across the system.',
                  icon: Icons.analytics_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComplaintManagementScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  title: 'Manage Users',
                  subtitle:
                      'Verify pending accounts and maintain admin access for city staff.',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageAdminsScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
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
              child: Icon(icon, color: const Color(0xFF153B9E)),
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
