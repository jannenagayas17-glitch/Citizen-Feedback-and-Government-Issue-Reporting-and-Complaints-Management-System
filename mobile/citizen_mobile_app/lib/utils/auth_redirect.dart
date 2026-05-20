import 'package:flutter/material.dart';

import 'app_routes.dart';

class AuthRedirect {
  static String normalizeRole(Object? role) {
    final normalized = (role ?? 'citizen').toString().trim().toLowerCase();
    if (normalized == 'staff') {
      return 'admin';
    }
    if (normalized == 'front_desk') {
      return 'administrative_staff';
    }
    return normalized;
  }

  static String routeForRole(Object? role) {
    switch (normalizeRole(role)) {
      case 'administrative_staff':
        return AppRoutes.frontDeskHome;
      case 'citizen':
        return AppRoutes.citizenHome;
      default:
        return AppRoutes.login;
    }
  }

  static void goToRoleHome(BuildContext context, Object? role) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeForRole(role),
      (route) => false,
    );
  }
}
