import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';

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
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  late RegisterMode _selectedMode;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _departmentController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _accessCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  Color get _primaryColor {
    return _selectedMode == RegisterMode.citizen
        ? const Color(0xFF2E6CF6)
        : const Color(0xFF8A2BE2);
  }

  String get _headerTitle {
    return _selectedMode == RegisterMode.citizen
        ? 'Create Account'
        : 'Request Government Account';
  }

  String get _headerSubtitle {
    return _selectedMode == RegisterMode.citizen
        ? 'Join CivicReport as a citizen'
        : 'Official access requires verification';
  }

  String get _googleButtonText {
    return _selectedMode == RegisterMode.citizen
        ? 'Sign up with Google'
        : 'Sign up with Google';
  }

  Future<void> _registerCitizen() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnack('Please fill in all required fields');
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      if (!mounted) return;

      final user = data['user'] as Map<String, dynamic>;
      final role = user['role']?.toString() ?? 'citizen';

      _showSnack('Account created successfully');

      if (role == 'super_admin') {
        Navigator.pushReplacementNamed(context, '/super-admin-home');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin-home');
      } else {
        Navigator.pushReplacementNamed(context, '/citizen-home');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestGovernmentAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final department = _departmentController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final accessCode = _accessCodeController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        department.isEmpty ||
        jobTitle.isEmpty ||
        accessCode.isEmpty ||
        password.isEmpty) {
      _showSnack('Please fill in all required fields');
      return;
    }

    // TODO: connect this to your Laravel request-account API later
    _showSnack('Government account request flow is not connected yet');
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _googleAuthService.signInWithGoogle();
      final user = credential.user;

      if (!mounted) return;

      if (user == null) {
        _showSnack('Google sign-up failed');
        return;
      }

      _showSnack('Signed in as ${user.email ?? 'Google User'}');

      // TODO:
      // Send Firebase token to Laravel and route by role.
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _submit() {
    if (_selectedMode == RegisterMode.citizen) {
      _registerCitizen();
    } else {
      _requestGovernmentAccount();
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
    _departmentController.dispose();
    _jobTitleController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCitizen = _selectedMode == RegisterMode.citizen;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 36),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF163DAD),
                          Color(0xFF0E2D8C),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 40, 0, 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0A0E6A),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4C7BFF).withOpacity(0.25),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'CIVIC REPORT',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tacloban City Government · Your Voice Matters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD7E3FF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isCitizen
                                            ? const Color(0xFFE8F0FF)
                                            : const Color(0xFFF0E8FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCitizen
                                            ? Icons.person_outline
                                            : Icons.business_outlined,
                                        color: _primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _headerTitle,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _headerSubtitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(color: Color(0xFFE5E7EB)),
                                const SizedBox(height: 18),

                                _buildGoogleButton(),
                                const SizedBox(height: 16),
                                _buildDivider(),
                                const SizedBox(height: 16),

                                if (!isCitizen) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E8),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFF3D7A3),
                                      ),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Color(0xFFE28A12),
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Government portal access is restricted to authorized city officials. You will need a valid government access code from your IT department.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFB35B00),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                _buildLabel('Full Name *'),
                                _buildInputField(
                                  controller: _nameController,
                                  hint: isCitizen ? 'Jane Smith' : 'John Official',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 14),

                                _buildLabel(isCitizen ? 'Email Address *' : 'Official Email *'),
                                _buildInputField(
                                  controller: _emailController,
                                  hint: isCitizen
                                      ? 'jane@email.com'
                                      : 'official@taclobancity.gov',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),

                                _buildLabel(isCitizen ? 'Phone Number (optional)' : 'Phone (optional)'),
                                _buildInputField(
                                  controller: _phoneController,
                                  hint: '+63 9XX XXX XXXX',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 14),

                                if (!isCitizen) ...[
                                  _buildLabel('Department *'),
                                  _buildInputField(
                                    controller: _departmentController,
                                    hint: 'Department name',
                                    icon: Icons.apartment_outlined,
                                  ),
                                  const SizedBox(height: 14),

                                  _buildLabel('Job Title *'),
                                  _buildInputField(
                                    controller: _jobTitleController,
                                    hint: 'e.g. Field Supervisor',
                                    icon: Icons.badge_outlined,
                                  ),
                                  const SizedBox(height: 14),

                                  _buildLabel('Government Access Code *'),
                                  _buildInputField(
                                    controller: _accessCodeController,
                                    hint: 'GOV-XXXX',
                                    icon: Icons.shield_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                _buildLabel('Password *'),
                                _buildPasswordField(
                                  controller: _passwordController,
                                  obscure: _obscurePassword,
                                  onToggle: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                  hint: 'Min. 8 characters',
                                ),
                                const SizedBox(height: 14),

                                if (isCitizen) ...[
                                  _buildLabel('Confirm Password *'),
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    obscure: _obscureConfirmPassword,
                                    onToggle: () {
                                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                    },
                                    hint: 'Repeat password',
                                  ),
                                  const SizedBox(height: 18),
                                ] else
                                  const SizedBox(height: 18),

                                _buildPrimaryButton(
                                  text: isCitizen ? 'Create Account' : 'Request Account',
                                  onPressed: _submit,
                                  isLoading: _isLoading,
                                ),

                                const SizedBox(height: 16),

                                if (isCitizen)
                                  const Center(
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'By creating an account, you agree to Tacloban City\'s\n',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                          height: 1.5,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: Color(0xFF2E6CF6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy.',
                                            style: TextStyle(
                                              color: Color(0xFF2E6CF6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                      color: Color(0xFF6B7280),
                                    ),
                                    label: const Text(
                                      'Back to Sign In',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 0,
                    left: 24,
                    child: Text(
                      isCitizen ? 'Create Citizen Account' : 'Create Admin Account',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _signUpWithGoogle,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isGoogleLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _primaryColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _googleButtonText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or fill in your details',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: Color(0xFF9CA3AF),
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: const Color(0xFF9CA3AF),
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 10,
          shadowColor: _primaryColor.withOpacity(0.35),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}