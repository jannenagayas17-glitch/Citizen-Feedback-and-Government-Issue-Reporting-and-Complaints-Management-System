import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'utils/app_theme_controller.dart';
import 'utils/app_routes.dart';
import 'utils/portal_session_controller.dart';

const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  },
);

final ThemeData _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF5F8FC),
  pageTransitionsTheme: _pageTransitionsTheme,
);

final ThemeData _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E6CF6),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF0C1727),
  pageTransitionsTheme: _pageTransitionsTheme,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
            title: 'Admin Portal',
            navigatorKey: PortalSessionController.navigatorKey,
            themeMode: themeController.themeMode,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeAnimationDuration: Duration.zero,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
