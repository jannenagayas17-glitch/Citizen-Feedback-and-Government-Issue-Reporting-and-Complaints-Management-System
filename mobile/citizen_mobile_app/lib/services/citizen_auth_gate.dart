import '../utils/token_storage.dart';
import '../utils/auth_redirect.dart';
import 'auth_service.dart';

enum CitizenAuthDestination { login, citizenHome, frontDeskHome }

class CitizenAuthGateResult {
  const CitizenAuthGateResult._({
    required this.destination,
    this.user,
    this.shouldClearStoredSession = false,
  });

  const CitizenAuthGateResult.login({bool shouldClearStoredSession = false})
    : this._(
        destination: CitizenAuthDestination.login,
        shouldClearStoredSession: shouldClearStoredSession,
      );

  const CitizenAuthGateResult.citizenHome(Map<String, dynamic> user)
    : this._(destination: CitizenAuthDestination.citizenHome, user: user);

  const CitizenAuthGateResult.frontDeskHome(Map<String, dynamic> user)
    : this._(destination: CitizenAuthDestination.frontDeskHome, user: user);

  final CitizenAuthDestination destination;
  final Map<String, dynamic>? user;
  final bool shouldClearStoredSession;

  bool get shouldOpenCitizenHome =>
      destination == CitizenAuthDestination.citizenHome && user != null;

  bool get shouldOpenFrontDeskHome =>
      destination == CitizenAuthDestination.frontDeskHome && user != null;
}

class CitizenAuthGate {
  CitizenAuthGate({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<CitizenAuthGateResult> resolve() async {
    final token = (await TokenStorage.getToken())?.trim() ?? '';
    if (token.isEmpty) {
      return const CitizenAuthGateResult.login(shouldClearStoredSession: true);
    }

    try {
      final user = await _authService.getCurrentUser();
      final role = AuthRedirect.normalizeRole(user['role']);

      if (role == 'citizen') {
        return CitizenAuthGateResult.citizenHome(user);
      }

      if (role == 'administrative_staff') {
        return CitizenAuthGateResult.frontDeskHome(user);
      }

      if (role != 'citizen') {
        return const CitizenAuthGateResult.login(
          shouldClearStoredSession: true,
        );
      }

      return const CitizenAuthGateResult.login(shouldClearStoredSession: true);
    } catch (_) {
      return const CitizenAuthGateResult.login(shouldClearStoredSession: true);
    }
  }
}
