import '../utils/auth_redirect.dart';
import '../utils/token_storage.dart';
import 'auth_service.dart';

class PortalAuthGateResult {
  const PortalAuthGateResult._({
    required this.normalizedRole,
    required this.user,
    required this.shouldClearStoredSession,
    this.message,
  });

  const PortalAuthGateResult.login({
    bool shouldClearStoredSession = false,
    String? message,
  }) : this._(
         normalizedRole: null,
         user: null,
         shouldClearStoredSession: shouldClearStoredSession,
         message: message,
       );

  const PortalAuthGateResult.roleHome(
    String role,
    Map<String, dynamic> user, {
    String? message,
  }) : this._(
         normalizedRole: role,
         user: user,
         shouldClearStoredSession: false,
         message: message,
       );

  final String? normalizedRole;
  final Map<String, dynamic>? user;
  final bool shouldClearStoredSession;
  final String? message;

  bool get shouldOpenLogin => normalizedRole == null || user == null;
}

class PortalAuthGate {
  PortalAuthGate({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<PortalAuthGateResult> resolve() async {
    final token = (await TokenStorage.getToken())?.trim() ?? '';

    if (token.isEmpty) {
      return const PortalAuthGateResult.login(shouldClearStoredSession: true);
    }

    try {
      final user = await _authService.getCurrentUser();
      final normalizedRole = AuthRedirect.normalizeRole(user['role']);

      if (normalizedRole != 'admin' && normalizedRole != 'super_admin') {
        return const PortalAuthGateResult.login(
          shouldClearStoredSession: true,
          message: 'Please log in with an admin account.',
        );
      }

      return PortalAuthGateResult.roleHome(normalizedRole, user);
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      return PortalAuthGateResult.login(
        shouldClearStoredSession: true,
        message: message.isEmpty
            ? 'Session expired. Please log in again.'
            : message,
      );
    }
  }
}
