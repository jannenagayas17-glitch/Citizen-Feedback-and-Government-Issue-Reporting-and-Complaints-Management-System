import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/citizen/citizen_home_screen.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
import 'utils/app_routes.dart';
import 'utils/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tacloban City Engineering Office',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6CF6),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const _StartupGate(),
      routes: AppRoutes.routes,
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  Future<Widget> _resolveStartScreen() async {
    final token = await TokenStorage.getToken();
    final role = (await TokenStorage.getRole())?.trim().toLowerCase();

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    if (role == 'super_admin') {
      return const SuperAdminDashboard();
    }

    if (role == 'admin' || role == 'staff') {
      return const AdminHomeScreen();
    }

    return const CitizenHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Color(0xFF0C1727));
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
