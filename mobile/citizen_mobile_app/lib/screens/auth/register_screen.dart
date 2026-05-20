import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../utils/app_routes.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_auth_scaffold.dart';
import '../../widgets/citizen_branding.dart';
import '../../widgets/citizen_policy_sheet.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const int _maxNameLength = 25;
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );
  static final RegExp _nameRegex = RegExp(r"^[A-Za-z]+(?:[ '-][A-Za-z]+)*$");
  static final RegExp _phMobileSubscriberRegex = RegExp(r'^9\d{9}$');
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
  bool _isNormalizingPhone = false;
  bool _acceptedPolicies = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _policyError;

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

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  String _normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizePhoneInput(String value) {
    var digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('63') && digitsOnly.length <= 12) {
      digitsOnly = digitsOnly.substring(2);
    } else if (digitsOnly.startsWith('0') && digitsOnly.length <= 11) {
      digitsOnly = digitsOnly.substring(1);
    }

    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    return digitsOnly;
  }

  String _buildSubmissionPhone(String value) {
    return '+63${_normalizePhoneInput(value)}';
  }

  String? _validateName(String label, String value) {
    final normalized = _normalizeWhitespace(value);

    if (normalized.isEmpty) {
      return '$label is required.';
    }

    if (_containsEmoji(normalized)) {
      return 'Emoji characters are not allowed.';
    }

    if (normalized.length > _maxNameLength) {
      return '$label must be 25 characters or fewer.';
    }

    if (!_nameRegex.hasMatch(normalized)) {
      return '$label can only contain letters, spaces, hyphens, and apostrophes.';
    }

    return null;
  }

  String? _validatePhone(String value) {
    final normalized = _normalizePhoneInput(value);

    if (normalized.isEmpty) {
      return 'Mobile number is required.';
    }

    if (!_phMobileSubscriberRegex.hasMatch(normalized)) {
      return 'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.';
    }

    return null;
  }

  void _handlePhoneChanged(String value) {
    final normalized = _normalizePhoneInput(value);

    if (!_isNormalizingPhone && normalized != value) {
      _isNormalizingPhone = true;
      _phoneController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      _isNormalizingPhone = false;
    }

    if (_phoneError != null) {
      setState(() => _phoneError = null);
    }
  }

  void _clearErrors() {
    _firstNameError = null;
    _lastNameError = null;
    _emailError = null;
    _phoneError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _policyError = null;
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    final firstName = _normalizeWhitespace(_firstNameController.text);
    final lastName = _normalizeWhitespace(_lastNameController.text);
    final name = '$firstName $lastName'.trim();
    final email = _emailController.text.trim();
    final phone = _buildSubmissionPhone(_phoneController.text);
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _clearErrors();

      _firstNameError = _validateName('First name', firstName);
      _lastNameError = _validateName('Last name', lastName);

      if (email.isEmpty) {
        _emailError = 'Email address is required.';
      } else if (_containsEmoji(email)) {
        _emailError = 'Emoji characters are not allowed.';
      } else if (!_isValidEmail(email)) {
        _emailError = 'Enter a valid email address.';
      }

      _phoneError = _validatePhone(_phoneController.text);

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

      if (!_acceptedPolicies) {
        _policyError =
            'You must agree to the Terms & Conditions and Privacy Policy to continue.';
      }
    });

    if (_firstNameError != null ||
        _lastNameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _confirmPasswordError != null ||
        _policyError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        name: name,
        email: email,
        mobileNumber: phone,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      final user = data['user'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? '').trim().toLowerCase();

      if (role.isNotEmpty && role != 'citizen') {
        throw Exception('This app only supports citizen registrations.');
      }

      CitizenDataCache.clear();
      await _authService.clearLocalSession();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
        arguments: LoginRouteArguments(
          successMessage:
              'Registration successful. Please log in with your new account.',
          prefilledEmail: email,
        ),
      );
    } catch (e) {
      await _authService.clearLocalSession();
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

  Future<void> _openPolicyDocument(CitizenPolicyDocument document) {
    return CitizenPolicySheet.show(context, initialDocument: document);
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
    return CitizenAuthScaffold(
      child: CitizenAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CitizenBrandHeader(
                caption: 'Citizen Registration',
                logoSize: 92,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.86),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            const CitizenSectionDivider(label: 'Account Information'),
            const SizedBox(height: 16),
            CitizenTextField(
              controller: _firstNameController,
              label: 'First Name',
              hintText: 'Your first name',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(
                Icons.person_outline,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.deny(_emojiRegex),
                LengthLimitingTextInputFormatter(_maxNameLength),
              ],
              errorText: _firstNameError,
              onChanged: (_) {
                if (_firstNameError != null) {
                  setState(() => _firstNameError = null);
                }
              },
            ),
            const SizedBox(height: 14),
            CitizenTextField(
              controller: _lastNameController,
              label: 'Last Name',
              hintText: 'Your last name',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.deny(_emojiRegex),
                LengthLimitingTextInputFormatter(_maxNameLength),
              ],
              errorText: _lastNameError,
              onChanged: (_) {
                if (_lastNameError != null) {
                  setState(() => _lastNameError = null);
                }
              },
            ),
            const SizedBox(height: 14),
            CitizenTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: _emailHint,
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
            const SizedBox(height: 14),
            CitizenTextField(
              controller: _phoneController,
              label: 'Mobile Number',
              hintText: '9123456789',
              keyboardType: TextInputType.phone,
              prefixIcon: Icon(
                Icons.call_outlined,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              prefixText: '+63 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              errorText: _phoneError,
              onChanged: _handlePhoneChanged,
            ),
            const SizedBox(height: 14),
            CitizenTextField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Create a password',
              obscureText: _obscurePassword,
              prefixIcon: Icon(
                Icons.lock_outline,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
              errorText: _passwordError,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
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
            ),
            const SizedBox(height: 14),
            CitizenTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hintText: 'Confirm your password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icon(
                Icons.lock_outline,
                color: CitizenAppPalette.sand.withValues(alpha: 0.82),
              ),
              inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
              errorText: _confirmPasswordError,
              onChanged: (_) {
                if (_confirmPasswordError != null) {
                  setState(() => _confirmPasswordError = null);
                }
              },
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: CitizenAppPalette.sand.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acceptedPolicies,
                  onChanged: (value) {
                    setState(() {
                      _acceptedPolicies = value ?? false;
                      if (_acceptedPolicies) {
                        _policyError = null;
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),
                Expanded(child: _buildPolicyAcceptanceText()),
              ],
            ),
            if (_policyError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 46),
                child: Text(
                  _policyError!,
                  style: TextStyle(
                    color: CitizenAppPalette.error.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            CitizenPrimaryButton(
              label: 'Register',
              onPressed: _submit,
              loading: _isLoading,
              height: 52,
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
                child: const Text('Already have an account? Login here'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyAcceptanceText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            Text(
              'I agree to the ',
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.88),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            _InlinePolicyButton(
              label: 'Terms & Conditions',
              onTap: () => _openPolicyDocument(CitizenPolicyDocument.terms),
            ),
            Text(
              ' and ',
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.88),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            _InlinePolicyButton(
              label: 'Privacy Policy',
              onTap: () => _openPolicyDocument(CitizenPolicyDocument.privacy),
            ),
            Text(
              '. I understand that uploaded evidence and complaint details may be reviewed by authorized personnel for verification and resolution.',
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.88),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlinePolicyButton extends StatelessWidget {
  const _InlinePolicyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: CitizenAppPalette.sand,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: CitizenAppPalette.sand,
        ),
      ),
    );
  }
}
