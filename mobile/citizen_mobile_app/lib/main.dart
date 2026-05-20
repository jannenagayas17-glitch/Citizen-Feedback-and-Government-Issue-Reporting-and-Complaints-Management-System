import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'utils/app_routes.dart';
import 'utils/citizen_app_theme.dart';
import 'utils/app_theme_controller.dart';

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
            title: 'Citizen Feedback',
            themeMode: themeController.themeMode,
            theme: CitizenAppTheme.light(),
            darkTheme: CitizenAppTheme.dark(),
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
