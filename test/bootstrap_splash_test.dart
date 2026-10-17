import 'dart:async';

import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_flow_models.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/startup_brand_sequence.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/startup_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_storage.dart';

/// Session cleanup that finishes only when the test completes it.
final _slowCleanup = Completer<void>();

class _SlowSession extends AuthSessionNotifier {
  @override
  Future<void> clear() => _slowCleanup.future;
}

class _LoadingProfile extends StartupGateNotifier {
  @override
  NotifierState<StartupGateData> build() => const NotifierState.loading(
    data: StartupGateData(stage: StartupGateStage.loadingProfile),
  );
}

Future<ProviderContainer> _pumpBootstrap(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({hasSeenOnboardingKey: true});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: MemorySecureStorage()),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: const BootstrapScreen(),
      ),
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(BootstrapScreen)),
  );
}

void main() {
  testWidgets('a cold launch holds the splash for the minimum duration and '
      'keeps it while routing', (tester) async {
    final container = await _pumpBootstrap(tester);
    await tester.pump();

    expect(find.byType(StartupBrandSequence), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2699));
    expect(container.read(authNavigationProvider), isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      container.read(authNavigationProvider).single.destination,
      AuthDestination.login,
    );
    expect(find.byType(StartupBrandSequence), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('slow cleanup publishes as soon as it finishes', (tester) async {
    final container = await _pumpBootstrap(
      tester,
      overrides: [authSessionProvider.overrideWith(_SlowSession.new)],
    );
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(authNavigationProvider), isEmpty);

    _slowCleanup.complete();
    await tester.pump();
    expect(
      container.read(authNavigationProvider).single.destination,
      AuthDestination.login,
    );
  });

  testWidgets('the post-login profile load shows the spinner, not the splash', (
    tester,
  ) async {
    await _pumpBootstrap(
      tester,
      overrides: [startupGateProvider.overrideWith(_LoadingProfile.new)],
    );

    expect(find.byType(StartupBrandSequence), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your account…'), findsOneWidget);
  });
}
