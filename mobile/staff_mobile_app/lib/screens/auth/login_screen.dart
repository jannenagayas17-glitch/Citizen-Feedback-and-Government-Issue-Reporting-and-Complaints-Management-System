import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/auth_redirect.dart';
import '../../utils/token_storage.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum LoginMode { admin, superAdmin }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static const String _configuredSuperAdminEmail = String.fromEnvironment(
    'SUPER_ADMIN_EMAIL',
    defaultValue: 'cityengineer@gov.ph',
  );

  final AuthService _authService = AuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginMode _selectedMode = LoginMode.admin;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _emailError;
  String? _passwordError;

  bool get _isSuperAdminMode => _selectedMode == LoginMode.superAdmin;
  _LoginModeConfig get _modeConfig => _LoginModeConfig.fromMode(_selectedMode);
  bool get _showGoogleLogin => !_isSuperAdminMode;
  bool get _isSuperAdminEmailLocked =>
      _isSuperAdminMode && _resolvedSuperAdminEmail.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSavedEmailForMode();
  }

  String get _resolvedSuperAdminEmail {
    final configured = _configuredSuperAdminEmail.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    return '';
  }

  bool _isAllowedForSelection(String role) {
    final normalized = AuthRedirect.normalizeRole(role);
    return normalized == _modeConfig.expectedRole;
  }

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  void _clearErrors() {
    _emailError = null;
    _passwordError = null;
  }

  Future<void> _loadSavedEmailForMode() async {
    if (_isSuperAdminEmailLocked) {
      _emailController.text = _resolvedSuperAdminEmail;
      return;
    }

    final rememberedEmail = await TokenStorage.getLastEmailForRole(
      _modeConfig.expectedRole,
    );

    if (!mounted) return;

    setState(() {
      _emailController.text = rememberedEmail?.trim() ?? '';
    });
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _clearErrors();

      if (email.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (_containsEmoji(email)) {
        _emailError = 'Emoji characters are not allowed.';
      } else {
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(email)) {
          _emailError = 'Enter a valid email address.';
        }
      }

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
      } else if (_containsEmoji(password)) {
        _passwordError = 'Emoji characters are not allowed.';
      }
    });

    if (_emailError != null || _passwordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _authService.login(
        email: email,
        password: password,
      );

      final user = data['user'] as Map<String, dynamic>? ?? {};
      final role = AuthRedirect.normalizeRole(user['role']);

      if (!mounted) return;

      if (!_isAllowedForSelection(role)) {
        await TokenStorage.clearAll();
        _showSnackBar(_modeConfig.unauthorizedMessage);
        return;
      }

      await TokenStorage.saveLastEmailForRole(
        role: role,
        email: email,
      );

      if (!mounted) return;
      AuthRedirect.goToRoleHome(context, role);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isSuperAdminMode) {
      _showSnackBar('Super admin must sign in with email and password.');
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _googleAuthService.signInWithGoogle();
      final user = credential.user;

      if (!mounted) return;

      if (user == null) {
        _showSnackBar('Google sign-in failed');
        return;
      }

      final idToken = await user.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Unable to get Google ID token');
      }

      final data = await _authService.loginWithGoogle(
        idToken: idToken,
        email: user.email,
        name: user.displayName,
      );
      final backendUser = data['user'] as Map<String, dynamic>? ?? {};
      final role = AuthRedirect.normalizeRole(backendUser['role']);

      if (!mounted) return;

      if (!_isAllowedForSelection(role)) {
        await TokenStorage.clearAll();
        _showSnackBar(_modeConfig.unauthorizedMessage);
        return;
      }

      await TokenStorage.saveLastEmailForRole(
        role: role,
        email: user.email ?? '',
      );

      if (!mounted) return;
      AuthRedirect.goToRoleHome(context, role);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _openRegisterScreen() {
    if (_isSuperAdminMode) {
      _showSnackBar('Super admin accounts are created by the system only.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  void _openForgotPasswordScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleModeChange(LoginMode mode) async {
    setState(() {
      _selectedMode = mode;
      _passwordController.clear();
    });

    await _loadSavedEmailForMode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
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
                                padding: const EdgeInsets.all(10),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'City Engineering Portal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Admin & Super Admin Access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SectionDivider(
                            label: 'SIGN IN',
                            color: Colors.white.withOpacity(0.75),
                          ),
                          const SizedBox(height: 18),
                          _fieldLabel('Login As'),
                          const SizedBox(height: 8),
                          _buildModeDropdown(),
                          const SizedBox(height: 16),
                          _fieldLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hintText: _modeConfig.emailHint,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isSuperAdminEmailLocked,
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
                          const SizedBox(height: 16),
                          _fieldLabel('Password'),
                          const SizedBox(height: 8),
                          _buildPasswordField(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openForgotPasswordScreen,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.68),
                                    fontSize: 13,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: ' Forgot password?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_showGoogleLogin) ...[
                            const SizedBox(height: 4),
                            _SectionDivider(
                              label: 'Or continue with',
                              color: Colors.white.withOpacity(0.62),
                            ),
                            const SizedBox(height: 18),
                            _buildGoogleButton(),
                          ],
                          const SizedBox(height: 16),
                          _buildLoginButton(),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _isSuperAdminMode ? null : _openRegisterScreen,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withOpacity(0.84),
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: _isSuperAdminMode
                                      ? Colors.white.withOpacity(0.55)
                                      : Colors.white.withOpacity(0.72),
                                  fontSize: 14,
                                ),
                                children: _modeConfig.bottomTextSpans(
                                  highlightedColor: _isSuperAdminMode
                                      ? Colors.white.withOpacity(0.55)
                                      : Colors.white,
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

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildModeDropdown() {
    return DropdownButtonFormField<LoginMode>(
      value: _selectedMode,
      dropdownColor: const Color(0xFF5B534E),
      iconEnabledColor: Colors.white.withOpacity(0.9),
      decoration: _inputDecoration(
        hintText: '',
        icon: Icons.keyboard_arrow_down_rounded,
        usePrefixIcon: false,
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      items: const [
        DropdownMenuItem(
          value: LoginMode.admin,
          child: Text('Admin'),
        ),
        DropdownMenuItem(
          value: LoginMode.superAdmin,
          child: Text('Super Admin'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        _handleModeChange(value);
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      autofillHints: keyboardType == TextInputType.emailAddress
          ? const [AutofillHints.username, AutofillHints.email]
          : null,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        hintText: hintText,
        icon: icon,
      ).copyWith(
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      inputFormatters: [
        FilteringTextInputFormatter.deny(_emojiRegex),
      ],
      onChanged: (_) {
        if (_passwordError != null) {
          setState(() => _passwordError = null);
        }
      },
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _isLoading ? null : _login(),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        hintText: '........',
        icon: Icons.lock_outline,
      ).copyWith(
        errorText: _passwordError,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontSize: 12,
        ),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white.withOpacity(0.72),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    bool usePrefixIcon = true,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.5),
      ),
      prefixIcon: usePrefixIcon
          ? Icon(icon, color: Colors.white.withOpacity(0.72), size: 20)
          : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.14),
          side: BorderSide(color: Colors.white.withOpacity(0.18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/google_logo.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _LoginModeConfig {
  const _LoginModeConfig({
    required this.expectedRole,
    required this.emailHint,
    required this.unauthorizedMessage,
  });

  final String expectedRole;
  final String emailHint;
  final String unauthorizedMessage;

  factory _LoginModeConfig.fromMode(LoginMode mode) {
    switch (mode) {
      case LoginMode.admin:
        return const _LoginModeConfig(
          expectedRole: 'admin',
          emailHint: 'official@taclobancity.gov',
          unauthorizedMessage: 'This account is not authorized for admin login.',
        );
      case LoginMode.superAdmin:
        return const _LoginModeConfig(
          expectedRole: 'super_admin',
          emailHint: 'superadmin@taclobancity.gov',
          unauthorizedMessage:
              'This email is not registered as a super admin account.',
        );
    }
  }

  List<InlineSpan> bottomTextSpans({
    required Color highlightedColor,
  }) {
    if (expectedRole == 'super_admin') {
      return [
        TextSpan(
          text: 'Super admin accounts are created by the system only',
          style: TextStyle(
            color: highlightedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ];
    }

    return [
      const TextSpan(text: 'Need an admin account? '),
      TextSpan(
        text: 'Register here',
        style: TextStyle(
          color: highlightedColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withOpacity(0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withOpacity(0.35))),
      ],
    );
  }
}
