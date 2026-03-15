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
    switch (normalizeRole(role)) {
      case 'super_admin':
        return AppRoutes.superAdminHome;
      case 'admin':
        return AppRoutes.adminHome;
      default:
        return AppRoutes.citizenHome;
    }
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
