import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_auth_scaffold.dart';
import '../../widgets/citizen_branding.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

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
          response['message']?.toString() ??
          'Password reset link sent successfully';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMailApp(String email) async {
    final gmailInboxUri = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
    final gmailSchemeUri = Uri.parse('googlegmail:///');
    final genericMailUri = Uri(scheme: 'mailto', path: email);

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
    return CitizenAuthScaffold(
      child: CitizenAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: CitizenAppPalette.sand.withValues(alpha: 0.72),
                ),
              ),
            ),
            const CitizenBrandHeader(caption: 'Account Recovery', logoSize: 92),
            const SizedBox(height: 18),
            const CitizenSectionDivider(label: 'Reset your password'),
            const SizedBox(height: 18),
            Text(
              "No worries. Enter your account email and we'll send you a secure reset link.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
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
            const SizedBox(height: 18),
            CitizenPrimaryButton(
              label: 'Send Reset Link',
              onPressed: _sendResetLink,
              loading: _isLoading,
              height: 50,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
