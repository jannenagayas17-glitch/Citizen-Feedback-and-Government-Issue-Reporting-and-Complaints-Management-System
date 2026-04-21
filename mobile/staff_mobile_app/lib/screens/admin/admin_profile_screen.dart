import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/app_routes.dart';
import '../auth/forgot_password_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({
    super.key,
    required this.user,
    required this.onOpenReports,
    required this.onOpenUsers,
    this.manageUsersLabel = 'Manage users',
    this.manageUsersSubtitle = 'Review admin and citizen accounts',
    this.showManageUsers = true,
  });

  final Map<String, dynamic> user;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenUsers;
  final String manageUsersLabel;
  final String manageUsersSubtitle;
  final bool showManageUsers;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AuthService _authService = AuthService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isSaving = false;
  bool _isLoggingOut = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.user['name'] ?? 'Admin User').toString(),
    );
    _emailController = TextEditingController(
      text: (widget.user['email'] ?? '').toString(),
    );
    _phoneController = TextEditingController(
      text: (widget.user['mobile_number'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _prettyRole(String role) {
    if (role.trim().isEmpty) return 'Administrator';
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

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) return officeName;
    }
    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Department' : department;
  }

  String get _roleLabel {
    final role = (widget.user['role'] ?? 'admin').toString();
    if (role == 'admin') return 'Administrator';
    return _prettyRole(role);
  }

  String get _jobTitle {
    final title = (widget.user['job_title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    return _roleLabel;
  }

  String get _department => _departmentLabel(widget.user);

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'AD';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;

      if (name.isEmpty) {
        _nameError = 'Full name is required.';
      }

      if (email.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (!emailRegex.hasMatch(email)) {
        _emailError = 'Enter a valid email address.';
      }

      if (phone.isNotEmpty && !RegExp(r'^\d{11}$').hasMatch(phone)) {
        _phoneError = 'Phone number must be 11 digits.';
      }
    });

    return _nameError == null && _emailError == null && _phoneError == null;
  }

  Future<void> _saveProfile() async {
    if (!_validate()) return;

    setState(() => _isSaving = true);
    try {
      final response = await _authService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
      );

      final user = response['user'];
      if (user is Map<String, dynamic>) {
        widget.user
          ..['name'] = user['name']
          ..['email'] = user['email']
          ..['mobile_number'] = user['mobile_number'];
      } else {
        widget.user
          ..['name'] = _nameController.text.trim()
          ..['email'] = _emailController.text.trim()
          ..['mobile_number'] = _phoneController.text.trim();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

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
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Profile'),
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          22,
          isDesktop ? 26 : 16,
          22,
          24 + bottomSafeArea,
        ),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_box_rounded,
                size: 18,
                color: Color(0xFF4C6FFF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_department · ${_nameController.text.trim()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _profilePanel(),
          const SizedBox(height: 16),
          _appearancePanel(),
          const SizedBox(height: 16),
          _quickActionsPanel(),
        ],
      ),
    );
  }

  Widget _profilePanel() {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6D5EF8),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCED4E3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF13182A),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.trim().isEmpty
                          ? 'Admin User'
                          : _nameController.text.trim(),
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _jobTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _department,
                      style: TextStyle(
                        color: const Color(0xFF8993B7).withValues(alpha: 0.92),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 26),
          _fieldRow(
            label: 'Full Name',
            child: _profileField(
              controller: _nameController,
              hintText: 'Full name',
              errorText: _nameError,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 18),
          _fieldRow(
            label: 'Email Address',
            child: _profileField(
              controller: _emailController,
              hintText: 'Email address',
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: 18),
          _fieldRow(
            label: 'Phone Number',
            child: _profileField(
              controller: _phoneController,
              hintText: 'Optional',
              errorText: _phoneError,
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              OutlinedButton(
                onPressed: _openChangePassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.84),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  backgroundColor: const Color(0xFF161D2F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Change Password'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2557D6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(90, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearancePanel() {
    final colors = AdminThemeColors.of(context);
    final themeController = AppThemeScope.of(context);

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isDark = themeController.isDarkMode;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4C6FFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: const Color(0xFF4C6FFF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDark
                          ? 'Dark mode is saved for this admin account.'
                          : 'Light mode is saved for this admin account.',
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(value: isDark, onChanged: themeController.setDarkMode),
            ],
          ),
        );
      },
    );
  }

  Widget _quickActionsPanel() {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _actionButton(
            label: 'Reports',
            subtitle: 'Open queue',
            icon: Icons.assignment_outlined,
            onTap: widget.onOpenReports,
          ),
          if (widget.showManageUsers)
            _actionButton(
              label: widget.manageUsersLabel,
              subtitle: widget.manageUsersSubtitle,
              icon: Icons.groups_outlined,
              onTap: widget.onOpenUsers,
            ),
          _actionButton(
            label: 'Logout',
            subtitle: 'Sign out of this account',
            icon: Icons.logout_rounded,
            color: const Color(0xFFF87171),
            onTap: _isLoggingOut ? null : _logout,
            trailing: _isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _fieldRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF8E97B7).withValues(alpha: 0.86),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(child: child),
      ],
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String hintText,
    String? errorText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
        errorText: errorText,
        filled: true,
        fillColor: const Color(0xFF1A2032),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    Color color = const Color(0xFF4C6FFF),
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161D2F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
          ],
        ),
      ),
    );
  }
}
