import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );
  late final AuthService _authService;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;

  String get _subtitle {
    return 'Create your citizen account';
  }

  String get _emailHint {
    return 'your.email@example.com';
  }

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

  bool _isValidNamePart(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final partRegex = RegExp(r"^[A-Za-z]+(?:[.'-][A-Za-z]+)*\.?$");
    return partRegex.hasMatch(trimmed);
  }

  void _clearErrors() {
    _firstNameError = null;
    _lastNameError = null;
    _emailError = null;
    _phoneError = null;
    _passwordError = null;
    _confirmPasswordError = null;
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final name = '$firstName $lastName'.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _clearErrors();

      if (firstName.isEmpty) {
        _firstNameError = 'First name is required.';
      } else if (_containsEmoji(firstName)) {
        _firstNameError = 'Emoji characters are not allowed.';
      } else if (!_isValidNamePart(firstName)) {
        _firstNameError = 'Enter a valid first name.';
      }

      if (lastName.isEmpty) {
        _lastNameError = 'Last name is required.';
      } else if (_containsEmoji(lastName)) {
        _lastNameError = 'Emoji characters are not allowed.';
      } else if (!_isValidNamePart(lastName)) {
        _lastNameError = 'Enter a valid last name.';
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
    });

    if (_firstNameError != null ||
        _lastNameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _authService.register(
        name: name,
        email: email,
        mobileNumber: phone,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      final user = data['user'] as Map<String, dynamic>? ?? const {};
      final role = (user['role']?.toString() ?? '').trim().toLowerCase();

      if (role != 'citizen') {
        throw Exception('This app only supports citizen registrations.');
      }

      if (!mounted) return;

      CitizenDataCache.clear();
      await AppThemeScope.of(context).loadForUser(user);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.citizenHome,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
                  'assets/images/Tacloban_City_bg.png',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.10),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
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
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: const Color(0xFFD8B15A),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: SizedBox.expand(
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
                              color: Colors.white.withValues(alpha: 0.78),
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
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'ACCOUNT INFO',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontSize: 13,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('First Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _firstNameController,
                            hintText: 'your first name',
                            prefixIcon: Icons.person_outline,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _firstNameError,
                            onChanged: (_) {
                              if (_firstNameError != null) {
                                setState(() => _firstNameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Last Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _lastNameController,
                            hintText: 'your last name',
                            prefixIcon: Icons.badge_outlined,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            errorText: _lastNameError,
                            onChanged: (_) {
                              if (_lastNameError != null) {
                                setState(() => _lastNameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hintText: _emailHint,
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
                                color: Colors.white.withValues(alpha: 0.62),
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
                                color: Colors.white.withValues(alpha: 0.62),
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
                                disabledBackgroundColor: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.5),
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
                                foregroundColor: Colors.white.withValues(
                                  alpha: 0.84,
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 15,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Already have an account? '),
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
        color: Colors.white.withValues(alpha: 0.92),
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
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.white.withValues(alpha: 0.65),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.3),
        ),
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.3),
        ),
      ),
    );
  }
}
