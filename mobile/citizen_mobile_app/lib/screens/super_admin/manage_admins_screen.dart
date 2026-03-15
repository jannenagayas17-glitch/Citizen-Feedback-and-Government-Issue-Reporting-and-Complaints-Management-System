import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _authService.getAdminUsers();
  }

  Future<void> _refresh() async {
    final future = _authService.getAdminUsers();
    setState(() => _usersFuture = future);
    await future;
  }

  Future<void> _verify(int id) async {
    await _authService.verifyAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account verified successfully')),
    );
    await _refresh();
  }

  Future<void> _deactivate(int id) async {
    await _authService.deactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deactivated successfully')),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _usersFuture,
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

            final users = snapshot.data ?? const [];
            final pendingCount = users.where((user) {
              final role = ((user as Map<String, dynamic>)['role'] ?? 'citizen')
                  .toString();
              return role == 'pending_admin';
            }).length;
            final adminCount = users.where((user) {
              final role = ((user as Map<String, dynamic>)['role'] ?? 'citizen')
                  .toString();
              return role == 'admin' || role == 'super_admin';
            }).length;

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
                        'Administrator Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Review pending government accounts and manage elevated access for the Engineering Office.',
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
                    _SummaryCard(
                      label: 'Total Users',
                      value: '${users.length}',
                      color: const Color(0xFF2E6CF6),
                    ),
                    _SummaryCard(
                      label: 'Pending Review',
                      value: '$pendingCount',
                      color: const Color(0xFFF59E0B),
                    ),
                    _SummaryCard(
                      label: 'Admins',
                      value: '$adminCount',
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'User Directory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users found.'),
                    ),
                  )
                else
                  ...users.map((item) {
                    final user = item as Map<String, dynamic>;
                    final role = (user['role'] ?? 'citizen').toString();
                    final isPending = role == 'pending_admin';
                    final isElevated = role == 'admin' || role == 'super_admin';

                    return _UserCard(
                      name: (user['name'] ?? 'Unnamed User').toString(),
                      email: (user['email'] ?? '').toString(),
                      role: role,
                      onVerify: isPending ? () => _verify(user['id'] as int) : null,
                      onDeactivate: isElevated && role != 'super_admin'
                          ? () => _deactivate(user['id'] as int)
                          : null,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.email,
    required this.role,
    this.onVerify,
    this.onDeactivate,
  });

  final String name;
  final String email;
  final String role;
  final VoidCallback? onVerify;
  final VoidCallback? onDeactivate;

  Color _roleColor() {
    switch (role) {
      case 'super_admin':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFF16A34A);
      case 'pending_admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_outline, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (onVerify != null || onDeactivate != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onVerify != null)
                  ElevatedButton(
                    onPressed: onVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF153B9E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Verify'),
                  ),
                if (onVerify != null && onDeactivate != null)
                  const SizedBox(width: 10),
                if (onDeactivate != null)
                  OutlinedButton(
                    onPressed: onDeactivate,
                    child: const Text('Deactivate'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
