import 'package:flutter/material.dart';

import '../screens/admin/admin_home_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/super_admin/super_admin_dashboard.dart';
import 'protected_portal_route.dart';
import 'session_gate.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String adminHome = '/admin-home';
  static const String superAdminHome = '/super-admin-home';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SessionGate(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      adminHome: (context) => const ProtectedPortalRoute(
        allowedRoles: {'admin'},
        childBuilder: _buildAdminHome,
      ),
      superAdminHome: (context) => const ProtectedPortalRoute(
        allowedRoles: {'super_admin'},
        childBuilder: _buildSuperAdminHome,
      ),
    };
  }

  static Widget _buildAdminHome(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    return const AdminHomeScreen();
  }

  static Widget _buildSuperAdminHome(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    return const SuperAdminDashboard();
  }
}
