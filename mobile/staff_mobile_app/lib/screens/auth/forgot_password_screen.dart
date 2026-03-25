import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _emailError;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    setState(() {
      _emailError = null;

      if (email.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (_containsEmoji(email)) {
        _emailError = 'Emoji characters are not allowed.';
      } else if (!_isValidEmail(email)) {
        _emailError = 'Enter a valid email address.';
      }
    });

    if (_emailError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.forgotPassword(email: email);

      if (!mounted) return;

      final message =
          response['message']?.toString() ?? 'Password reset link sent successfully';

      _showSnack(message);
      _emailController.clear();
      await _openMailApp(email);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _emailError = message;
      });
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

  Future<void> _openMailApp(String email) async {
    final gmailInboxUri = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
    final gmailSchemeUri = Uri.parse('googlegmail:///');
    final genericMailUri = Uri(
      scheme: 'mailto',
      path: email,
    );

    if (await canLaunchUrl(gmailSchemeUri)) {
      await launchUrl(gmailSchemeUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(gmailInboxUri)) {
      await launchUrl(gmailInboxUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(genericMailUri)) {
      await launchUrl(genericMailUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.42),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                        color: const Color(0xFF121B31).withOpacity(0.92),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.24),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.72),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF163E9C).withOpacity(0.65),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_reset,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Forgot Password?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No worries! Enter your email and we'll send\nyou a reset link.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'Email Address',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'official@taclobancity.gov',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.white.withOpacity(0.65),
                                size: 20,
                              ),
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
                              errorText: _emailError,
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
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendResetLink,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
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
                                      'Send Reset Link',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Back to Login',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 14,
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
}
