import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/kyc_screens.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/login_screens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow_harness.dart';
import 'support/memory_secure_storage.dart';
import 'support/savings_fixtures.dart';

/// Secure storage holding a valid session left by a previous process.
Future<(MemorySecureStorage, SecureStorage)> _storedSession() async {
  final memory = MemorySecureStorage();
  final storage = SecureStorage(storage: memory);
  await storage.writeSession(savingsSession());
  return (memory, storage);
}

void main() {
  test('a returning user cold-launches to login and the stored session is '
      'cleared', () async {
    SharedPreferences.setMockInitialValues({hasSeenOnboardingKey: true});
    final preferences = await SharedPreferences.getInstance();
    final (memory, storage) = await _storedSession();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(startupGateProvider.notifier).start();

    final intent = container.read(authNavigationProvider).single;
    expect(intent.destination, AuthDestination.login);
    expect(intent.message, isNull);
    expect(container.read(authSessionProvider), isNull);
    expect(memory.values, isNot(contains(storage.accessTokenKey)));
    expect(memory.values, isNot(contains(storage.authSessionKey)));
  });

  testWidgets('a private deep link cannot restore a stored session', (
    tester,
  ) async {
    final (_, storage) = await _storedSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: (_) => [
            // Not Home, so it goes through SavingsAccessGate.
            AppRouter.onGenerateRoute(
              const RouteSettings(name: AppRoutes.tierOverview),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(KycTiersScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  test(
    'a stored token without a session in this process is never sent',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://auth.test'))
        ..interceptors.addAll([
          AuthInterceptor(
            readAccessToken: () async => savingsSession().accessToken,
            readCurrentSession: () => null,
            expireSessionOnce: () async {},
            isPublicOperation: (_, _) => false,
          ),
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(requestOptions: options, statusCode: 200),
              );
            },
          ),
        ]);
      addTearDown(dio.close);

      await dio.get<Object?>('/users/me/profile');

      expect(requests.single.headers, isNot(contains('Authorization')));
    },
  );
}
