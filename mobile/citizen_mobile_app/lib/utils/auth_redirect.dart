import 'package:flutter/material.dart';

import 'app_routes.dart';

class AuthRedirect {
  static String normalizeRole(Object? role) {
    final normalized = (role ?? 'citizen').toString().trim().toLowerCase();
    if (normalized == 'staff') {
      return 'admin';
    }
    return normalized;
  }

  static String routeForRole(Object? role) {
    return normalizeRole(role) == 'citizen'
        ? AppRoutes.citizenHome
        : AppRoutes.login;
  }

  static void goToRoleHome(
    BuildContext context,
    Object? role,
  ) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeForRole(role),
      (route) => false,
    );
  }
}
