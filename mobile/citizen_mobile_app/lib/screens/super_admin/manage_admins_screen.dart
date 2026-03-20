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
  int? _currentUserId;
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _usersFuture = _authService.getAdminUsers();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUserId = user['id'] as int?;
        _currentUserRole = (user['role'] ?? '').toString();
      });
    } catch (_) {
      // Keep the screen usable even if the current user request fails.
    }
  }

  Future<void> _refresh() async {
    final future = _authService.getAdminUsers();
    setState(() {
      _usersFuture = future;
    });
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF233246),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Deactivate Account?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'This will remove elevated access and sign the account out of active sessions. You can still reactivate access later if needed.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.82)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _authService.deactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deactivated successfully')),
    );
    await _refresh();
  }

  Future<void> _reactivate(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF233246),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Reactivate Account?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'This will restore account access so the user can sign in again.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.82)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _authService.reactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account reactivated successfully')),
    );
    await _refresh();
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
          title: const Text('Account Directory'),
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
          child: FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _GlassMessageCard(
                      title: 'Unable to load users',
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                    ),
                  ],
                );
              }

              final users = snapshot.data ?? const [];
              final pendingCount = users.where((user) {
                final record = user as Map<String, dynamic>;
                final role = (record['role'] ?? 'citizen').toString();
                final isActive = record['is_active'] != false;
                return role == 'pending_admin' && isActive;
              }).length;
              final adminCount = users.where((user) {
                final record = user as Map<String, dynamic>;
                final role = (record['role'] ?? 'citizen').toString();
                final isActive = record['is_active'] != false;
                return isActive && (role == 'admin' || role == 'super_admin');
              }).length;

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomSafeArea),
                children: [
                  const _UsersHeroCard(),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth > 520
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryCard(
                            width: cardWidth,
                            label: 'Total Users',
                            value: '${users.length}',
                            color: const Color(0xFF60A5FA),
                            icon: Icons.groups_outlined,
                          ),
                          _SummaryCard(
                            width: cardWidth,
                            label: 'Pending Review',
                            value: '$pendingCount',
                            color: const Color(0xFFF59E0B),
                            icon: Icons.fact_check_outlined,
                          ),
                          _SummaryCard(
                            width: cardWidth,
                            label: 'Elevated Access',
                            value: '$adminCount',
                            color: const Color(0xFF22C55E),
                            icon: Icons.admin_panel_settings_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'User Directory',
                    subtitle:
                        'Review citizens and staff accounts, verify pending admins, and manage access safely.',
                  ),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const _GlassMessageCard(
                      title: 'No users found',
                      message:
                          'User records will appear here once accounts are available.',
                    )
                  else
                    ...users.map((item) {
                      final user = item as Map<String, dynamic>;
                      final role = (user['role'] ?? 'citizen').toString();
                      final isActive = user['is_active'] != false;
                      final isPending = role == 'pending_admin';
                      final isSelf = user['id'] == _currentUserId;
                      final canDeactivate = _canDeactivateRole(
                        role,
                        isSelf,
                        isActive,
                      );
                      final canReactivate = _canReactivateRole(
                        role,
                        isSelf,
                        isActive,
                      );

                      return _UserCard(
                        name: (user['name'] ?? 'Unnamed User').toString(),
                        email: (user['email'] ?? '').toString(),
                        role: role,
                        isActive: isActive,
                        onVerify:
                            isPending ? () => _verify(user['id'] as int) : null,
                        onDeactivate: canDeactivate
                            ? () => _deactivate(user['id'] as int)
                            : null,
                        onReactivate: canReactivate
                            ? () => _reactivate(user['id'] as int)
                            : null,
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

  bool _canDeactivateRole(String targetRole, bool isSelf, bool isActive) {
    if (isSelf || targetRole == 'super_admin' || !isActive) {
      return false;
    }

    if (_currentUserRole == 'super_admin') {
      return targetRole == 'citizen' ||
          targetRole == 'admin' ||
          targetRole == 'pending_admin';
    }

    if (_currentUserRole == 'admin') {
      return targetRole == 'citizen';
    }

    return false;
  }

  bool _canReactivateRole(String targetRole, bool isSelf, bool isActive) {
    if (isSelf || targetRole == 'super_admin' || isActive) {
      return false;
    }

    return _currentUserRole == 'super_admin';
  }
}

class _UsersHeroCard extends StatelessWidget {
  const _UsersHeroCard();

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
                  'Administrator Management',
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
            'Review pending government accounts, verify trusted staff, and keep privileged access tightly controlled.',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final Color color;
  final IconData icon;

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
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.onVerify,
    this.onDeactivate,
    this.onReactivate,
  });

  final String name;
  final String email;
  final String role;
  final bool isActive;
  final VoidCallback? onVerify;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  Color _roleColor() {
    switch (role) {
      case 'super_admin':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFF22C55E);
      case 'pending_admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _roleLabel() {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'pending_admin':
        return 'Pending Review';
      case 'citizen':
        return 'Citizen';
      default:
        return 'Citizen';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor();
    final statusColor = isActive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RoleChip(label: _roleLabel(), color: color),
                  const SizedBox(height: 8),
                  _RoleChip(
                    label: isActive ? 'Active' : 'Deactivated',
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
          if (onVerify != null || onDeactivate != null || onReactivate != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onVerify != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onVerify,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Verify'),
                    ),
                  ),
                if (onVerify != null && onDeactivate != null)
                  const SizedBox(width: 10),
                if (onVerify != null && onDeactivate == null && onReactivate != null)
                  const SizedBox(width: 10),
                if (onDeactivate != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeactivate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.20)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Deactivate'),
                    ),
                  ),
                if (onDeactivate != null && onReactivate != null)
                  const SizedBox(width: 10),
                if (onReactivate != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onReactivate,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Reactivate'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
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
          fontWeight: FontWeight.w700,
          fontSize: 11,
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
