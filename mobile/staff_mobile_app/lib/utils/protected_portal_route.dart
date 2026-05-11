import 'package:flutter/material.dart';

import '../services/portal_auth_gate.dart';
import 'app_theme_controller.dart';
import 'auth_redirect.dart';
import 'portal_session_notice.dart';
import 'token_storage.dart';

typedef ProtectedPortalChildBuilder =
    Widget Function(BuildContext context, Map<String, dynamic> user);

class ProtectedPortalRoute extends StatefulWidget {
  const ProtectedPortalRoute({
    super.key,
    required this.allowedRoles,
    required this.childBuilder,
    this.authGate,
  });

  final Set<String> allowedRoles;
  final ProtectedPortalChildBuilder childBuilder;
  final PortalAuthGate? authGate;

  @override
  State<ProtectedPortalRoute> createState() => _ProtectedPortalRouteState();
}

class _ProtectedPortalRouteState extends State<ProtectedPortalRoute> {
  Map<String, dynamic>? _user;
  bool _redirectScheduled = false;

  PortalAuthGate get _authGate => widget.authGate ?? PortalAuthGate();

  @override
  void initState() {
    super.initState();
    _resolveAccess();
  }

  Future<void> _resolveAccess() async {
    final result = await _authGate.resolve();

    if (result.shouldClearStoredSession) {
      await TokenStorage.clearAll();
    }

    if (!mounted) return;

    if (result.shouldOpenLogin) {
      _redirectToLogin(result.message);
      return;
    }

    final normalizedRole = result.normalizedRole ?? '';
    if (!widget.allowedRoles.contains(normalizedRole)) {
      _redirectToRoleHome(
        normalizedRole,
        result.message ?? 'This account cannot access that page.',
      );
      return;
    }

    final user = result.user!;
    await AppThemeScope.of(context).loadForUser(user);

    if (!mounted) return;

    setState(() => _user = user);
  }

  void _redirectToLogin(String? message) {
    if (_redirectScheduled) {
      return;
    }

    _redirectScheduled = true;
    if (message != null && message.trim().isNotEmpty) {
      PortalSessionNotice.store(message);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  void _redirectToRoleHome(String normalizedRole, String? message) {
    if (_redirectScheduled) {
      return;
    }

    _redirectScheduled = true;
    if (message != null && message.trim().isNotEmpty) {
      PortalSessionNotice.store(message);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AuthRedirect.routeForRole(normalizedRole),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      return widget.childBuilder(context, _user!);
    }

    return const _PortalRouteLoadingView();
  }
}

class _PortalRouteLoadingView extends StatelessWidget {
  const _PortalRouteLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ColoredBox(
        color: Color(0xFF0C1727),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
