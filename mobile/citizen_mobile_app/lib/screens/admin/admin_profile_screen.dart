import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({
    super.key,
    required this.user,
    required this.onOpenReports,
    required this.onOpenUsers,
    this.manageUsersLabel = 'Manage users',
    this.manageUsersSubtitle = 'Review admin and citizen accounts',
  });

  final Map<String, dynamic> user;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenUsers;
  final String manageUsersLabel;
  final String manageUsersSubtitle;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  String _prettyRole(String role) {
    if (role.trim().isEmpty) return 'Admin';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final name = (widget.user['name'] ?? 'Admin User').toString();
    final email = (widget.user['email'] ?? 'No email').toString();
    final mobile = (widget.user['mobile_number'] ?? 'No mobile number')
        .toString();
    final role = (widget.user['role'] ?? 'admin').toString();
    final department = (widget.user['department'] ?? 'Engineering Office')
        .toString();
    final jobTitle = (widget.user['job_title'] ?? 'Staff').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1727), Color(0xFF1E293B), Color(0xFF463327)],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomSafeArea),
          children: [
            _buildHeroCard(name, email, role, department),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.badge_outlined,
                    label: 'Role',
                    value: _prettyRole(role),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.call_outlined,
                    label: 'Mobile',
                    value: mobile == 'No mobile number' ? 'Not set' : mobile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.apartment_outlined,
                    label: 'Department',
                    value: department,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.work_outline_rounded,
                    label: 'Job Title',
                    value: jobTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.assignment_outlined,
                    title: 'Report queue',
                    subtitle: 'Review and update submitted complaints',
                    onTap: widget.onOpenReports,
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _ActionTile(
                    icon: Icons.groups_outlined,
                    title: widget.manageUsersLabel,
                    subtitle: widget.manageUsersSubtitle,
                    onTap: widget.onOpenUsers,
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _ActionTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of this staff account',
                    iconColor: const Color(0xFFFF7B7B),
                    titleColor: const Color(0xFFFF7B7B),
                    trailing: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: _isLoggingOut ? null : _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    String name,
    String email,
    String role,
    String department,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: const Color(0xFFD8B15A), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 10),
          Text(
            department,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              _prettyRole(role),
              style: const TextStyle(
                color: Color(0xFFB8D3FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF9DBEFF)),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = Colors.white,
    this.titleColor = Colors.white,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color titleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      ),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap,
    );
  }
}
