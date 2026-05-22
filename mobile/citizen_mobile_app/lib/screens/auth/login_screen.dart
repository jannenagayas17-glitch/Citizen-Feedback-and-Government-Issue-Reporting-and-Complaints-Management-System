import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';
import '../../services/citizen_avatar_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/google_auth_service.dart';
import '../../utils/auth_redirect.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../utils/token_storage.dart';
import '../../widgets/citizen_auth_scaffold.dart';
import '../../widgets/citizen_branding.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService, this.googleAuthService});

  final AuthService? authService;
  final GoogleAuthService? googleAuthService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  late final AuthService _authService;
  GoogleAuthService? _googleAuthService;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _handledRouteArguments = false;
  bool _shouldKeepRoutePrefilledEmail = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _loadSavedEmail();
  }

  GoogleAuthService get _resolvedGoogleAuthService =>
      _googleAuthService ??= widget.googleAuthService ?? GoogleAuthService();

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  void _clearErrors() {
    _emailError = null;
    _passwordError = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_handledRouteArguments) {
      return;
    }

    _handledRouteArguments = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! LoginRouteArguments) {
      return;
    }

    final prefilledEmail = arguments.prefilledEmail?.trim() ?? '';
    if (prefilledEmail.isNotEmpty) {
      _shouldKeepRoutePrefilledEmail = true;
      _emailController.text = prefilledEmail;
    }

    final successMessage = arguments.successMessage?.trim() ?? '';
    if (successMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSnackBar(successMessage);
      });
    }
  }

  Future<void> _resetGoogleSession() async {
    try {
      await _resolvedGoogleAuthService.signOut();
    } catch (_) {
      // Keep the login flow resilient even if Firebase cleanup fails.
    }
  }

  Future<void> _loadSavedEmail() async {
    final rememberedEmail =
        await TokenStorage.getLastEmailForRole('citizen') ??
        await TokenStorage.getLastEmailForRole('administrative_staff');

    if (!mounted || _shouldKeepRoutePrefilledEmail) return;

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
      final data = await _authService.login(email: email, password: password);

      final user = data['user'] as Map<String, dynamic>? ?? {};
      final role = AuthRedirect.normalizeRole(user['role']);

      if (!mounted) return;

      if (role != 'citizen' && role != 'administrative_staff') {
        CitizenDataCache.clear();
        await TokenStorage.clearAll();
        _showSnackBar(
          'This mobile app is for citizen and administrative staff accounts only. Please use the web admin portal for admin access.',
        );
        return;
      }

      final themeController = AppThemeScope.of(context);
      CitizenDataCache.clear();
      CitizenDataCache.updateUser(user);
      CitizenAvatarService.syncFromUser(user);
      await TokenStorage.saveLastEmailForRole(role: role, email: email);
      await themeController.loadForUser(user);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AuthRedirect.routeForRole(role),
        (route) => false,
      );
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
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _resolvedGoogleAuthService.signInWithGoogle();
      final user = credential.user;

      if (!mounted) return;

      if (user == null) {
        await _resetGoogleSession();
        _showSnackBar('Google sign-in failed');
        return;
      }

      final idToken = await user.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Unable to get Google ID token');
      }

      final data = await _authService.loginWithGoogle(
        idToken: idToken,
        roleHint: 'citizen',
        email: user.email,
        name: user.displayName,
      );

      final backendUser = data['user'] as Map<String, dynamic>? ?? {};
      final role = AuthRedirect.normalizeRole(backendUser['role']);

      if (!mounted) return;

      if (role != 'citizen') {
        await _resetGoogleSession();
        CitizenDataCache.clear();
        await TokenStorage.clearAll();
        _showSnackBar(
          role == 'administrative_staff'
              ? 'Administrative staff accounts should sign in with their assigned email and password.'
              : 'This mobile app is for citizen accounts only when using Google sign-in. Please use the web admin portal for admin access.',
        );
        return;
      }

      final themeController = AppThemeScope.of(context);
      CitizenDataCache.clear();
      CitizenDataCache.updateUser(backendUser);
      CitizenAvatarService.syncFromUser(backendUser);
      await TokenStorage.saveLastEmailForRole(
        role: 'citizen',
        email: user.email ?? '',
      );
      await themeController.loadForUser(backendUser);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.citizenHome,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      await _resetGoogleSession();
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _openRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _openForgotPasswordScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CitizenAuthScaffold(
      child: CitizenAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CitizenBrandHeader(
                caption: 'Citizen Sign In',
                logoSize: 112,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.98),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Citizens can sign in to submit reports and track updates. Administrative staff can also use their assigned account to assist walk-in complainants.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.86),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            const CitizenSectionDivider(label: 'Use your email account'),
            const SizedBox(height: 18),
            CitizenTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'your.email@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(
                Icons.email_outlined,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
              errorText: _emailError,
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPasswordScreen,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 16),
            _buildLoginButton(),
            const SizedBox(height: 18),
            const CitizenSectionDivider(label: 'Or continue with Google'),
            const SizedBox(height: 16),
            _buildGoogleButton(),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _openRegisterScreen,
              child: const Text("Don't have an account? Register here"),
            ),
            const SizedBox(height: 6),
            Text(
              'Front desk accounts are created by the super admin and must use email and password sign-in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.78),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return CitizenTextField(
      controller: _passwordController,
      label: 'Password',
      hintText: 'Enter your password',
      inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
      onChanged: (_) {
        if (_passwordError != null) {
          setState(() => _passwordError = null);
        }
      },
      obscureText: _obscurePassword,
      errorText: _passwordError,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _isLoading ? null : _login(),
      prefixIcon: Icon(
        Icons.lock_outline,
        color: CitizenAppPalette.sand.withValues(alpha: 0.82),
      ),
      suffixIcon: IconButton(
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: CitizenAppPalette.sand.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: citizenIsDark(context)
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.96),
          side: BorderSide(color: citizenGlassBorderColor(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isGoogleLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: citizenHighlightColor(context),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/google_logo.svg',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: citizenTitleColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return CitizenPrimaryButton(
      label: 'Sign In',
      onPressed: _login,
      loading: _isLoading,
      height: 54,
    );
  }
}
