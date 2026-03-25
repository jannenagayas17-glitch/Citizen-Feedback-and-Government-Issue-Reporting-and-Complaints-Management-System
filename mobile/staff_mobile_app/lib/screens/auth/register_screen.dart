import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static const List<String> _adminTypes = [
    'Assistant City Engineer',
    'Engineering Office Supervisor',
    'Engineering Staff/ Office Coordinator',
  ];

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
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _adminTypeError;
  String? _selectedAdminType;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\d{11}$').hasMatch(phone);
  }

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  bool _isValidFullName(String name) {
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

  void _clearErrors() {
    _nameError = null;
    _emailError = null;
    _phoneError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _adminTypeError = null;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _clearErrors();

      if (name.isEmpty) {
        _nameError = 'Full name is required.';
      } else if (_containsEmoji(name)) {
        _nameError = 'Emoji characters are not allowed.';
      } else if (!_isValidFullName(name)) {
        _nameError = 'Enter your full name with first and last name.';
      }

      if (email.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (_containsEmoji(email)) {
        _emailError = 'Emoji characters are not allowed.';
      } else if (!_isValidEmail(email)) {
        _emailError = 'Enter a valid email address.';
      }

      if (phone.isEmpty) {
        _phoneError = 'Mobile number is required.';
      } else if (!_isValidPhone(phone)) {
        _phoneError = 'Mobile number must be exactly 11 digits.';
      }

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
      } else if (_containsEmoji(password)) {
        _passwordError = 'Emoji characters are not allowed.';
      } else if (password.length < 8) {
        _passwordError = 'Password must be at least 8 characters.';
      }

      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Please confirm your password.';
      } else if (_containsEmoji(confirmPassword)) {
        _confirmPasswordError = 'Emoji characters are not allowed.';
      } else if (password != confirmPassword) {
        _confirmPasswordError = 'Passwords do not match.';
      }

      if (_selectedAdminType == null) {
        _adminTypeError = 'Please select an admin type.';
      }
    });

    if (_nameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _confirmPasswordError != null ||
        _adminTypeError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
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

      _showSnack(
        response['message']?.toString() ??
            'Admin account request submitted successfully',
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/engineering_office_bg.png',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1727).withValues(alpha: 0.62),
                  ),
                ),
              ],
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
                            'Request Admin Access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Register for an official engineering office account',
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
                              setState(() {
                                _selectedAdminType = value;
                                _adminTypeError = null;
                              });
                            },
                            errorText: _adminTypeError,
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Full Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hintText: 'your full name',
                            prefixIcon: Icons.person_outline,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _nameError,
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'official@taclobancity.gov',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _emailError,
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Mobile Number'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _phoneController,
                            hintText: '09XX XXX XXXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.call_outlined,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            errorText: _phoneError,
                            onChanged: (_) {
                              if (_phoneError != null) {
                                setState(() => _phoneError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: '........',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _passwordError,
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
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
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _confirmPasswordError,
                            onChanged: (_) {
                              if (_confirmPasswordError != null) {
                                setState(() => _confirmPasswordError = null);
                              }
                            },
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
                                      text: 'Already have a staff account? ',
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
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
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
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontSize: 12,
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(
            color: Color(0xFFEF4444),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(
            color: Color(0xFFEF4444),
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
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFEF4444)
                  : Colors.white.withOpacity(0.2),
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
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              color: Color(0xFFFFB4B4),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
