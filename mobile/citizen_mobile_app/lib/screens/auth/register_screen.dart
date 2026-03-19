import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/auth_redirect.dart';
import '../../utils/app_routes.dart';

enum RegisterMode { citizen, government }

class RegisterScreen extends StatefulWidget {
  final RegisterMode initialMode;

  const RegisterScreen({
    super.key,
    this.initialMode = RegisterMode.citizen,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  RegisterMode _selectedMode = RegisterMode.citizen;
  String? _selectedAdminType;

  static const List<String> _adminTypes = [
    'Assistant City Engineer',
    'Engineering Office Supervisor',
    'Engineering Staff/ Office Coordinator',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  bool get _isCitizenMode => _selectedMode == RegisterMode.citizen;

  String get _subtitle {
    return _isCitizenMode
        ? 'Create your citizen account'
        : 'Register for an official account';
  }

  String get _emailHint {
    return _isCitizenMode
        ? 'your.email@example.com'
        : 'official@taclobancity.gov';
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnack('Please fill in all required fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnack('Enter a valid email address');
      return;
    }

    if (!_isValidPhone(phone)) {
      _showSnack('Enter a valid mobile number');
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Passwords do not match');
      return;
    }

    if (!_isCitizenMode && _selectedAdminType == null) {
      _showSnack('Please select an admin type');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isCitizenMode) {
        final data = await _authService.register(
          name: name,
          email: email,
          mobileNumber: phone,
          password: password,
          passwordConfirmation: confirmPassword,
        );

        if (!mounted) return;

        final user = data['user'] as Map<String, dynamic>? ?? {};
        final role = AuthRedirect.normalizeRole(user['role']);
        AuthRedirect.goToRoleHome(context, role);
      } else {
        final response = await _authService.requestGovernmentAccount(
          name: name,
          email: email,
          mobileNumber: phone,
          password: password,
          department: 'Tacloban City Engineering Office',
          jobTitle: _selectedAdminType!,
          accessCode: 'GOV-REQUEST',
        );

        if (!mounted) return;

        final user = response['user'] as Map<String, dynamic>?;
        final token = response['token'];
        if (user != null && token != null) {
          AuthRedirect.goToRoleHome(context, user['role']);
          return;
        }

        _showSnack(
          response['message']?.toString() ??
              'Admin account request submitted successfully',
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
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
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.22),
                            Colors.white.withOpacity(0.10),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.16),
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
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 31,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'ACCOUNT INFO',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    fontSize: 13,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Account Role'),
                          const SizedBox(height: 8),
                          _buildDropdownField<RegisterMode>(
                            value: _selectedMode,
                            items: const [
                              DropdownMenuItem(
                                value: RegisterMode.citizen,
                                child: Text('Citizen'),
                              ),
                              DropdownMenuItem(
                                value: RegisterMode.government,
                                child: Text('Admin'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedMode = value;
                                if (_isCitizenMode) {
                                  _selectedAdminType = null;
                                }
                              });
                            },
                          ),
                          if (!_isCitizenMode) ...[
                            const SizedBox(height: 14),
                            _buildLabel('Admin Type'),
                            const SizedBox(height: 8),
                            _buildDropdownField<String>(
                              value: _selectedAdminType,
                              hint: 'Select admin type',
                              items: _adminTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedAdminType = value);
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          _buildLabel('Full Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hintText: 'your full name',
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hintText: _emailHint,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Mobile Number'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _phoneController,
                            hintText: '09XX XXX XXXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.call_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: '........',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white.withOpacity(0.62),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Confirm Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hintText: '........',
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white.withOpacity(0.62),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF2563EB).withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Register',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (route) => false,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.84),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 15,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Already have an account? ',
                                    ),
                                    TextSpan(
                                      text: 'Login here',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.white.withOpacity(0.65),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(
            color: Color(0xFF3B82F6),
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF394355),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.8),
          ),
          hint: hint == null
              ? null
              : Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 15,
                  ),
                ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}
