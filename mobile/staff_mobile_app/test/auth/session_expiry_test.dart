import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile_app/services/auth_service.dart';
import 'package:staff_mobile_app/utils/app_routes.dart';
import 'package:staff_mobile_app/utils/portal_session_controller.dart';
import 'package:staff_mobile_app/utils/portal_session_notice.dart';
import 'package:staff_mobile_app/utils/token_storage.dart';

import '../test_helpers.dart';

void main() {
  setupWidgetTestEnvironment();

  setUp(() {
    resetMockPreferences();
    PortalSessionNotice.consume();
  });

  testWidgets('session expiry clears auth state and redirects to login', (
    tester,
  ) async {
    configureTestViewport(tester);
    await TokenStorage.saveToken('portal-token');
    await TokenStorage.saveRole('super_admin');

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: PortalSessionController.navigatorKey,
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('login-page')),
        },
        home: const Scaffold(body: Text('portal-home')),
      ),
    );

    await tester.pumpAndSettle();

    await PortalSessionController.expireSession(
      message: 'Session expired. Please log in again.',
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('login-page'), findsOneWidget);
    expect(find.text('portal-home'), findsNothing);
    expect(await TokenStorage.getToken(), isNull);
    expect(await TokenStorage.getRole(), isNull);
    expect(
      PortalSessionNotice.consume(),
      'Session expired. Please log in again.',
    );
  });

  test('logout clears local auth even when remote logout fails', () async {
    await TokenStorage.saveToken('portal-token');
    await TokenStorage.saveRole('super_admin');

    await HttpOverrides.runZoned(() async {
      await AuthService().logout();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }, createHttpClient: (_) => _ThrowingHttpClient());

    expect(await TokenStorage.getToken(), isNull);
    expect(await TokenStorage.getRole(), isNull);
  });
}

class _ThrowingHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return Future<HttpClientRequest>.error(
      const SocketException('offline during logout'),
    );
  }
}
