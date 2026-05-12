import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import 'app_routes.dart';
import 'portal_session_notice.dart';
import 'token_storage.dart';

class PortalSessionController {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void>? _sessionExpiryFuture;

  static Future<void> clearStoredSession({bool signOutGoogle = false}) async {
    if (signOutGoogle) {
      try {
        await GoogleAuthService().signOut();
      } catch (_) {
        // Local logout must still complete even when Google/Firebase sign-out
        // is unavailable on the current platform or network.
      }
    }

    await TokenStorage.clearAll();
  }

  static Future<void> expireSession({String? message}) {
    final activeFuture = _sessionExpiryFuture;
    if (activeFuture != null) {
      return activeFuture;
    }

    final future = _expireSession(
      message: message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'Session expired. Please log in again.',
    );

    _sessionExpiryFuture = future;
    return future.whenComplete(() => _sessionExpiryFuture = null);
  }

  static Future<void> _expireSession({required String message}) async {
    await clearStoredSession(signOutGoogle: true);
    PortalSessionNotice.store(message);

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}
