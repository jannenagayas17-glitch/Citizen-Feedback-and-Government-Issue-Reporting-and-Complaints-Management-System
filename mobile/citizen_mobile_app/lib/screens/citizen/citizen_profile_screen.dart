import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';
import 'my_complaints_screen.dart';

class CitizenProfileScreen extends StatefulWidget {
  const CitizenProfileScreen({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<CitizenProfileScreen> createState() => _CitizenProfileScreenState();
}

class _CitizenProfileScreenState extends State<CitizenProfileScreen> {
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
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? 'Citizen').toString();
    final email = (widget.user['email'] ?? 'No email').toString();
    final mobile = (widget.user['mobile_number'] ?? 'No mobile number').toString();
    final role = (widget.user['role'] ?? 'citizen').toString();

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
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1E293B),
              Color(0xFF463327),
            ],
          ),
        ),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white.withOpacity(0.10),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                    child: Text(
                      name.isEmpty ? 'C' : name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProfileTile(
            icon: Icons.badge_outlined,
            title: 'Account role',
            value: role,
          ),
          _ProfileTile(
            icon: Icons.call_outlined,
            title: 'Mobile number',
            value: mobile,
          ),
          Card(
            color: Colors.white.withOpacity(0.10),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Colors.white),
                  title: const Text('My reports', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'View all your submitted complaints',
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyComplaintsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Color(0xFFDC2626),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Sign out of this citizen account',
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                  ),
                  trailing: _isLoggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
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
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.10),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          value,
          style: TextStyle(color: Colors.white.withOpacity(0.72)),
        ),
      ),
    );
  }
}
