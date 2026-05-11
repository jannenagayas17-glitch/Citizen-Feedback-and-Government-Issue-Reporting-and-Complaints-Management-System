import '../utils/token_storage.dart';
import 'auth_service.dart';

enum CitizenAuthDestination { login, citizenHome }

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

  final CitizenAuthDestination destination;
  final Map<String, dynamic>? user;
  final bool shouldClearStoredSession;

  bool get shouldOpenCitizenHome =>
      destination == CitizenAuthDestination.citizenHome && user != null;
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
      final role = (user['role'] ?? '').toString().trim().toLowerCase();

      if (role != 'citizen') {
        return const CitizenAuthGateResult.login(
          shouldClearStoredSession: true,
        );
      }

      return CitizenAuthGateResult.citizenHome(user);
    } catch (_) {
      return const CitizenAuthGateResult.login(shouldClearStoredSession: true);
    }
  }
}
