import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/app_routes.dart';
import '../../utils/validators.dart';

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
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isChangingPassword = false;
  bool _isNormalizingPhone = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

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
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _prettyRole(String role) {
    if (role.trim().isEmpty) {
      return 'Administrator';
    }

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
      if (officeName.isNotEmpty) {
        return officeName;
      }
    }

    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Assigned Department' : department;
  }

  String get _roleLabel {
    final role = (widget.user['role'] ?? 'admin').toString();
    return role == 'admin' ? 'Administrator' : _prettyRole(role);
  }

  String get _jobTitle {
    final title = (widget.user['job_title'] ?? '').toString().trim();
    if (title.isNotEmpty) {
      return title;
    }

    return _roleLabel;
  }

  String get _department => _departmentLabel(widget.user);

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return 'AD';
    }

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

  bool _validateProfile() {
    final name = PortalValidators.normalizeWhitespace(_nameController.text);
    final email = _emailController.text.trim();

    setState(() {
      _nameError = PortalValidators.validateFullName(name);
      _emailError = PortalValidators.validateEmail(email);
      _phoneError = PortalValidators.validatePhilippineMobile(
        _phoneController.text,
      );
    });

    return _nameError == null && _emailError == null && _phoneError == null;
  }

  bool _validatePasswordChange() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;

      if (currentPassword.trim().isEmpty) {
        _currentPasswordError = 'Current password is required.';
      } else if (PortalValidators.containsEmoji(currentPassword)) {
        _currentPasswordError = 'Emoji characters are not allowed.';
      }

      if (newPassword.isEmpty) {
        _newPasswordError = 'New password is required.';
      } else if (PortalValidators.containsEmoji(newPassword)) {
        _newPasswordError = 'Emoji characters are not allowed.';
      } else if (newPassword.length < 8) {
        _newPasswordError = 'New password must be at least 8 characters.';
      } else if (newPassword == currentPassword) {
        _newPasswordError =
            'New password must be different from the current password.';
      }

      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Confirm your new password.';
      } else if (confirmPassword != newPassword) {
        _confirmPasswordError = 'Password confirmation does not match.';
      }
    });

    return _currentPasswordError == null &&
        _newPasswordError == null &&
        _confirmPasswordError == null;
  }

  void _handlePhoneChanged(String value) {
    final sanitized = PortalValidators.sanitizeMobileInput(value);

    if (!_isNormalizingPhone && sanitized != value) {
      _isNormalizingPhone = true;
      _phoneController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      _isNormalizingPhone = false;
    }

    if (_phoneError != null) {
      setState(() => _phoneError = null);
    }
  }

  Future<void> _saveProfile() async {
    if (!_validateProfile()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await _authService.updateProfile(
        name: PortalValidators.normalizeWhitespace(_nameController.text),
        email: _emailController.text.trim(),
        mobileNumber: PortalValidators.buildSubmissionMobile(
          _phoneController.text,
        ),
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

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details saved successfully.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_validatePasswordChange()) {
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        newPasswordConfirmation: _confirmPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      setState(() {
        _currentPasswordError = null;
        _newPasswordError = null;
        _confirmPasswordError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafeArea = mediaQuery.padding.bottom;
    final isDesktop = mediaQuery.size.width >= 1100;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Settings'),
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
            ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 28 : 18,
          isDesktop ? 28 : 16,
          isDesktop ? 28 : 18,
          26 + bottomSafeArea + bottomInset,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: _buildBody(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerPanel(isDesktop: true),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _profilePanel(),
                    const SizedBox(height: 18),
                    _securityPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _identityPanel(),
                    const SizedBox(height: 18),
                    _appearancePanel(),
                    const SizedBox(height: 18),
                    _quickActionsPanel(),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerPanel(isDesktop: false),
        const SizedBox(height: 18),
        _identityPanel(),
        const SizedBox(height: 16),
        _profilePanel(),
        const SizedBox(height: 16),
        _securityPanel(),
        const SizedBox(height: 16),
        _appearancePanel(),
        const SizedBox(height: 16),
        _quickActionsPanel(),
      ],
    );
  }

  Widget _headerPanel({required bool isDesktop}) {
    final colors = AdminThemeColors.of(context);
    final headingStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w800,
      height: 1.05,
    );

    final subheadingStyle = TextStyle(
      color: colors.mutedText,
      fontSize: isDesktop ? 14 : 13,
      height: 1.45,
    );

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? const [Color(0xFF1A2940), Color(0xFF132035), Color(0xFF251E33)]
              : const [Color(0xFFF9FBFF), Color(0xFFE9F3FF), Color(0xFFF4F8FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.14)
                : const Color(0xFFB8D5FF).withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _headerCopy(headingStyle, subheadingStyle)),
                const SizedBox(width: 18),
                _heroBadge(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCopy(headingStyle, subheadingStyle),
                const SizedBox(height: 18),
                _heroBadge(),
              ],
            ),
    );
  }

  Widget _headerCopy(TextStyle? headingStyle, TextStyle subheadingStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: headingStyle),
        const SizedBox(height: 10),
        Text(
          'Manage your account details, update your security settings, and keep '
          'your department workspace ready for day-to-day operations.',
          style: subheadingStyle,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metaPill(Icons.apartment_rounded, _department),
            _metaPill(Icons.badge_outlined, _roleLabel),
            _metaPill(Icons.mail_outline_rounded, _emailController.text.trim()),
          ],
        ),
      ],
    );
  }

  Widget _heroBadge() {
    final colors = AdminThemeColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: colors.isDark ? 0.34 : 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.70),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1D7BEA), Color(0xFF58B4FF)],
              ),
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.trim().isEmpty
                      ? 'Admin User'
                      : _nameController.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _jobTitle,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePanel() {
    final colors = AdminThemeColors.of(context);
    return _panelShell(
      title: 'Profile Details',
      subtitle: 'Keep the account name, email address, and contact number up to date.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _fieldBlock(
                label: 'Full Name',
                width: 320,
                child: _profileField(
                  controller: _nameController,
                  hintText: 'Full name',
                  errorText: _nameError,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(PortalValidators.emojiRegex),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _fieldBlock(
                label: 'Email Address',
                width: 320,
                child: _profileField(
                  controller: _emailController,
                  hintText: 'Email address',
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(PortalValidators.emojiRegex),
                  ],
                ),
              ),
              _fieldBlock(
                label: 'Phone Number',
                width: 320,
                child: _profileField(
                  controller: _phoneController,
                  hintText: 'Optional',
                  errorText: _phoneError,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  onChanged: _handlePhoneChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _summaryStat(
                  label: 'Department',
                  value: _department,
                  icon: Icons.account_tree_outlined,
                ),
                _summaryStat(
                  label: 'Access Level',
                  value: _roleLabel,
                  icon: Icons.verified_user_outlined,
                ),
                _summaryStat(
                  label: 'Contact',
                  value: _phoneController.text.trim().isEmpty
                      ? 'Not provided'
                      : _phoneController.text.trim(),
                  icon: Icons.phone_in_talk_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityPanel() {
    return _panelShell(
      title: 'Security',
      subtitle: 'Change the password for this admin account without leaving the settings page.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _fieldBlock(
                label: 'Current Password',
                width: 280,
                child: _passwordField(
                  controller: _currentPasswordController,
                  hintText: 'Enter current password',
                  errorText: _currentPasswordError,
                  obscureText: _obscureCurrentPassword,
                  onToggleVisibility: () {
                    setState(
                      () => _obscureCurrentPassword = !_obscureCurrentPassword,
                    );
                  },
                  onChanged: (_) {
                    if (_currentPasswordError != null) {
                      setState(() => _currentPasswordError = null);
                    }
                  },
                ),
              ),
              _fieldBlock(
                label: 'New Password',
                width: 280,
                child: _passwordField(
                  controller: _newPasswordController,
                  hintText: 'Minimum 8 characters',
                  errorText: _newPasswordError,
                  obscureText: _obscureNewPassword,
                  onToggleVisibility: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                  onChanged: (_) {
                    if (_newPasswordError != null) {
                      setState(() => _newPasswordError = null);
                    }
                  },
                ),
              ),
              _fieldBlock(
                label: 'Confirm Password',
                width: 280,
                child: _passwordField(
                  controller: _confirmPasswordController,
                  hintText: 'Re-enter the new password',
                  errorText: _confirmPasswordError,
                  obscureText: _obscureConfirmPassword,
                  onToggleVisibility: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  onChanged: (_) {
                    if (_confirmPasswordError != null) {
                      setState(() => _confirmPasswordError = null);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).panelAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminThemeColors.of(context).border),
            ),
            child: Text(
              'Use a strong password that is unique to this account. The new password '
              'must be different from the current one.',
              style: TextStyle(
                color: AdminThemeColors.of(context).mutedText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isChangingPassword ? null : _changePassword,
              icon: _isChangingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: Text(
                _isChangingPassword ? 'Updating...' : 'Update Password',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminThemeColors.of(context).text,
                side: BorderSide(color: AdminThemeColors.of(context).border),
                backgroundColor: AdminThemeColors.of(context).panelAlt,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityPanel() {
    final colors = AdminThemeColors.of(context);
    return _panelShell(
      title: 'Account Snapshot',
      subtitle: 'A quick summary of the signed-in admin profile and role scope.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2557D6), Color(0xFF60A5FA)],
                  ),
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
              const SizedBox(width: 16),
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
                        color: colors.mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _infoLine(Icons.apartment_rounded, 'Department', _department),
          _infoLine(Icons.badge_outlined, 'Role', _roleLabel),
          _infoLine(Icons.email_outlined, 'Email', _emailController.text.trim()),
          _infoLine(
            Icons.phone_outlined,
            'Phone',
            _phoneController.text.trim().isEmpty
                ? 'Not provided'
                : _phoneController.text.trim(),
          ),
        ],
      ),
    );
  }

  Widget _appearancePanel() {
    final themeController = AppThemeScope.of(context);

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final colors = AdminThemeColors.of(context);
        final isDark = themeController.isDarkMode;

        return _panelShell(
          title: 'Appearance',
          subtitle: 'Keep the portal comfortable to use during office hours and after-hours monitoring.',
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDark ? 'Dark mode enabled' : 'Light mode enabled',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your preference is saved for this admin account and applied across the portal.',
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 12,
                        height: 1.45,
                      ),
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
    return _panelShell(
      title: 'Quick Actions',
      subtitle: 'Jump back into high-traffic admin tasks without leaving the settings area.',
      child: Column(
        children: [
          _actionButton(
            label: 'Reports',
            subtitle: 'Open the department complaint queue',
            icon: Icons.assignment_outlined,
            onTap: widget.onOpenReports,
          ),
          if (widget.showManageUsers) ...[
            const SizedBox(height: 12),
            _actionButton(
              label: widget.manageUsersLabel,
              subtitle: widget.manageUsersSubtitle,
              icon: Icons.forum_outlined,
              onTap: widget.onOpenUsers,
            ),
          ],
          const SizedBox(height: 12),
          _actionButton(
            label: 'Logout',
            subtitle: 'Sign out of this account safely',
            icon: Icons.logout_rounded,
            color: const Color(0xFFDC2626),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.warningSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.warningBorder),
            ),
            child: Text(
              'Department data access stays limited to your assigned office. '
              'For account role changes, contact a super admin.',
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.10)
                : const Color(0xFF9DBBEA).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _fieldBlock({
    required String label,
    required double width,
    required Widget child,
  }) {
    final colors = AdminThemeColors.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String hintText,
    String? errorText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    final colors = AdminThemeColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      obscureText: obscureText,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.mutedText),
        errorText: errorText,
        filled: true,
        fillColor: colors.input,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return _profileField(
      controller: controller,
      hintText: hintText,
      obscureText: obscureText,
      errorText: errorText,
      onChanged: onChanged,
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AdminThemeColors.of(context).mutedText,
        ),
      ),
    );
  }

  Widget _summaryStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colors = AdminThemeColors.of(context);
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: colors.isDark ? 0.30 : 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final colors = AdminThemeColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.mutedText,
                ),
          ],
        ),
      ),
    );
  }
}
