import 'package:flutter/material.dart';

import '../screens/admin/admin_home_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/citizen/citizen_home_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/super_admin/super_admin_dashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String citizenHome = '/citizen-home';
  static const String adminHome = '/admin-home';
  static const String superAdminHome = '/super-admin-home';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      citizenHome: (context) => const CitizenHomeScreen(),
      adminHome: (context) => const AdminHomeScreen(),
      superAdminHome: (context) => const SuperAdminDashboard(),
    };
  }
}
