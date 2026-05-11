import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/services/portal_auth_gate.dart';
import 'package:staff_mobile_app/utils/app_routes.dart';
import 'package:staff_mobile_app/utils/app_theme_controller.dart';
import 'package:staff_mobile_app/utils/protected_portal_route.dart';
import 'package:staff_mobile_app/utils/token_storage.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
  });

  testWidgets('redirects expired direct super admin route to login', (
    tester,
  ) async {
    configureTestViewport(tester);
    await TokenStorage.saveToken('stale-token');

    final themeController = AppThemeController();

    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: MaterialApp(
          initialRoute: AppRoutes.superAdminHome,
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('login-page')),
            AppRoutes.superAdminHome: (_) => ProtectedPortalRoute(
              authGate: _FakePortalAuthGate(
                const PortalAuthGateResult.login(
                  shouldClearStoredSession: true,
                  message: 'Session expired. Please log in again.',
                ),
              ),
              allowedRoles: const {'super_admin'},
              childBuilder: (context, user) =>
                  const Scaffold(body: Text('super-admin-page')),
            ),
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('login-page'), findsOneWidget);
    expect(find.text('super-admin-page'), findsNothing);
    expect(await TokenStorage.getToken(), isNull);
  });

  testWidgets('redirects wrong role to the matching dashboard route', (
    tester,
  ) async {
    configureTestViewport(tester);
    await TokenStorage.saveToken('valid-token');

    final themeController = AppThemeController();

    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: MaterialApp(
          initialRoute: AppRoutes.superAdminHome,
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('login-page')),
            AppRoutes.adminHome: (_) =>
                const Scaffold(body: Text('admin-page')),
            AppRoutes.superAdminHome: (_) => ProtectedPortalRoute(
              authGate: _FakePortalAuthGate(
                PortalAuthGateResult.roleHome('admin', {
                  'id': 7,
                  'role': 'admin',
                  'email': 'admin@test.com',
                }),
              ),
              allowedRoles: const {'super_admin'},
              childBuilder: (context, user) =>
                  const Scaffold(body: Text('super-admin-page')),
            ),
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('admin-page'), findsOneWidget);
    expect(find.text('super-admin-page'), findsNothing);
  });
}

class _FakePortalAuthGate extends PortalAuthGate {
  _FakePortalAuthGate(this.result);

  final PortalAuthGateResult result;

  @override
  Future<PortalAuthGateResult> resolve() async => result;
}
