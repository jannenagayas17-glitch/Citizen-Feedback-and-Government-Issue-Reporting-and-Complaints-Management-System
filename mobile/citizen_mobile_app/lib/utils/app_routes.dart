import 'package:flutter/material.dart';

import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/citizen/citizen_home_screen.dart';
import '../screens/front_desk/front_desk_home_screen.dart';
import '../screens/splash/splash_screen.dart';

class LoginRouteArguments {
  const LoginRouteArguments({this.successMessage, this.prefilledEmail});

  final String? successMessage;
  final String? prefilledEmail;
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String citizenHome = '/citizen-home';
  static const String frontDeskHome = '/front-desk-home';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      citizenHome: (context) => const CitizenHomeScreen(),
      frontDeskHome: (context) => const FrontDeskHomeScreen(),
    };
  }
}
