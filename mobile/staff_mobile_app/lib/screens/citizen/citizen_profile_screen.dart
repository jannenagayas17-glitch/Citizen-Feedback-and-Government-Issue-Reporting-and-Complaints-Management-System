import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';
import 'my_complaints_screen.dart';

class _CitizenProfileValidators {
  static final RegExp emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static bool isValidFullName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return false;
    }

    final partRegex = RegExp(r"^[A-Za-z]+(?:[.'-][A-Za-z]+)*\.?$");
    return parts.every(partRegex.hasMatch);
  }

  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Full name is required.';
    if (emojiRegex.hasMatch(trimmed)) {
      return 'Emoji characters are not allowed.';
    }
    if (!isValidFullName(trimmed)) {
      return 'Enter your first and last name.';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email address is required.';
    if (emojiRegex.hasMatch(trimmed)) {
      return 'Emoji characters are not allowed.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validateMobile(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d{11}$').hasMatch(trimmed)) {
      return 'Mobile number must be exactly 11 digits.';
    }
    return null;
  }
}

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
  bool _isSavingProfile = false;
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
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

  Future<void> _openEditProfile() async {
    final updatedUser = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCitizenProfileSheet(
        initialName: (_user['name'] ?? '').toString(),
        initialEmail: (_user['email'] ?? '').toString(),
        initialMobile: (_user['mobile_number'] ?? '').toString(),
      ),
    );

    if (updatedUser == null || !mounted) {
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final response = await _authService.updateProfile(
        name: updatedUser['name'].toString(),
        email: updatedUser['email'].toString(),
        mobileNumber: updatedUser['mobile_number'].toString(),
      );

      if (!mounted) return;

      setState(() {
        _user = Map<String, dynamic>.from(response['user'] as Map<String, dynamic>);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user['name'] ?? 'Citizen').toString();
    final email = (_user['email'] ?? 'No email').toString();
    final mobile = (_user['mobile_number'] ?? 'No mobile number').toString();
    final role = (_user['role'] ?? 'citizen').toString();
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafeArea + 24),
        children: [
          _buildHeroCard(name, email, role),
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
          const SizedBox(height: 14),
          _buildActionCard(
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profile',
                  subtitle: 'Update your name, email, and mobile number',
                  trailing: _isSavingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, color: Colors.white),
                  onTap: _isSavingProfile ? null : _openEditProfile,
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.10)),
                _ActionTile(
                  icon: Icons.description_outlined,
                  title: 'My reports',
                  subtitle: 'View all your submitted complaints',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyComplaintsScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.10)),
                _ActionTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out of this citizen account',
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

  String _prettyRole(String role) {
    if (role.trim().isEmpty) return 'Citizen';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Widget _buildHeroCard(String name, String email, String role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFF2563EB).withOpacity(0.16),
            child: Text(
              name.isEmpty ? 'C' : name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9DBEFF),
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
            style: TextStyle(color: Colors.white.withOpacity(0.72)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.30)),
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
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: child,
    );
  }

}

class _EditCitizenProfileSheet extends StatefulWidget {
  const _EditCitizenProfileSheet({
    required this.initialName,
    required this.initialEmail,
    required this.initialMobile,
  });

  final String initialName;
  final String initialEmail;
  final String initialMobile;

  @override
  State<_EditCitizenProfileSheet> createState() => _EditCitizenProfileSheetState();
}

class _EditCitizenProfileSheetState extends State<_EditCitizenProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;

  String? _nameError;
  String? _emailError;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _mobileController = TextEditingController(text: widget.initialMobile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _nameError = _CitizenProfileValidators.validateName(_nameController.text);
      _emailError = _CitizenProfileValidators.validateEmail(_emailController.text);
      _mobileError = _CitizenProfileValidators.validateMobile(_mobileController.text);
    });

    if (_nameError != null || _emailError != null || _mobileError != null) {
      return;
    }

    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile_number': _mobileController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomSafeArea + 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121B31),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputLabel('Full name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              inputFormatters: [
                FilteringTextInputFormatter.deny(_CitizenProfileValidators.emojiRegex),
              ],
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: 'Enter your full name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Email address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              inputFormatters: [
                FilteringTextInputFormatter.deny(_CitizenProfileValidators.emojiRegex),
              ],
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: 'Enter your email',
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Mobile number'),
            const SizedBox(height: 8),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) {
                if (_mobileError != null) {
                  setState(() => _mobileError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: '09123456789',
                errorText: _mobileError,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _profileInputDecoration({
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        color: Color(0xFFFFB4B4),
        fontSize: 12,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
      ),
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
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF9DBEFF)),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
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
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.72)),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap,
    );
  }
}
