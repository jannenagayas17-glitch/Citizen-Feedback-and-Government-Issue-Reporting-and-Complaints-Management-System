import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/portal_auth_gate.dart';
import 'app_theme_controller.dart';
import 'auth_redirect.dart';
import 'portal_session_notice.dart';
import 'token_storage.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, this.authGate});

  final PortalAuthGate? authGate;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _showLogin = false;

  PortalAuthGate get _authGate => widget.authGate ?? PortalAuthGate();

  @override
  void initState() {
    super.initState();
    _routeFromSavedSession();
  }

  Future<void> _routeFromSavedSession() async {
    final result = await _authGate.resolve();

    if (result.shouldClearStoredSession) {
      await TokenStorage.clearAll();
    }

    if (!mounted) return;

    if (result.shouldOpenLogin) {
      if (result.message != null && result.message!.trim().isNotEmpty) {
        PortalSessionNotice.store(result.message!);
      }
      setState(() => _showLogin = true);
      return;
    }

    final role = result.normalizedRole!;
    final user = result.user!;
    final themeController = AppThemeScope.of(context);

    await TokenStorage.saveRole(role);
    if (!mounted) return;

    await themeController.loadForUser(user);

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, AuthRedirect.routeForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return const LoginScreen();
    }

    return const Scaffold(
      body: ColoredBox(
        color: Color(0xFF0C1727),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
