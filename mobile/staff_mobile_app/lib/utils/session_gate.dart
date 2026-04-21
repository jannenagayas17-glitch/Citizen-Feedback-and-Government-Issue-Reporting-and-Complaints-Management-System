import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import 'app_theme_controller.dart';
import 'auth_redirect.dart';
import 'token_storage.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    _routeFromSavedSession();
  }

  Future<void> _routeFromSavedSession() async {
    final token = await TokenStorage.getToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _showLogin = true);
      return;
    }

    try {
      final user = await AuthService().getCurrentUser();
      final role = AuthRedirect.normalizeRole(
        user['role'] ?? await TokenStorage.getRole(),
      );

      await TokenStorage.saveRole(role);
      if (mounted) {
        await AppThemeScope.of(context).loadForUser(user);
      }

      if (!mounted) return;

      final route = AuthRedirect.routeForRole(role);

      if (route == '/login') {
        await TokenStorage.clearAll();
        if (!mounted) return;
        setState(() => _showLogin = true);
        return;
      }

      Navigator.pushReplacementNamed(context, route);
    } catch (_) {
      await TokenStorage.clearAll();

      if (!mounted) return;

      setState(() => _showLogin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return const LoginScreen();
    }

    return const ColoredBox(color: Color(0xFF0C1727));
  }
}
