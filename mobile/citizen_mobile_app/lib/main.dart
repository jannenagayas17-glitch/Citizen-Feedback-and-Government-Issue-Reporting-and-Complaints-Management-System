import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/citizen/citizen_home_screen.dart';
import 'services/auth_service.dart';
import 'utils/app_routes.dart';
import 'utils/app_theme_controller.dart';
import 'utils/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Let the citizen app boot even if Firebase web setup is unavailable.
    // Email/password auth and regular report flows still use the Laravel API.
  }

  final themeController = AppThemeController();
  await themeController.load();

  runApp(MyApp(themeController: themeController));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeController});

  final AppThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Citizen Mobile App',
            themeMode: themeController.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E6CF6),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF6F8FC),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3B82F6),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF0C1727),
            ),
            home: const _StartupGate(),
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  Future<Widget> _resolveStartScreen(AppThemeController themeController) async {
    final token = await TokenStorage.getToken();
    final role = (await TokenStorage.getRole())?.trim().toLowerCase();

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    if (role != 'citizen') {
      await TokenStorage.clearAll();
      return const LoginScreen();
    }

    try {
      final user = await AuthService().getCurrentUser().timeout(
        const Duration(seconds: 6),
      );
      await themeController.loadForUser(user);
    } catch (_) {
      await TokenStorage.clearAll();
      return const LoginScreen();
    }

    return const CitizenHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeScope.of(context);

    return FutureBuilder<Widget>(
      future: _resolveStartScreen(themeController),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoading();
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0C1727),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: Color(0xFF93C5FD),
          ),
        ),
      ),
    );
  }
}
