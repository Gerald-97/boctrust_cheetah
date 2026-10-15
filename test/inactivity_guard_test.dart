import 'package:boctrust_savings_loan/app/auth_flow_listener.dart';
import 'package:boctrust_savings_loan/app/inactivity_guard.dart';
import 'package:boctrust_savings_loan/app/inactivity_policy.dart';
import 'package:boctrust_savings_loan/app/navigators.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

const _signedOut = '/login You were signed out after 3 minutes of inactivity.';

void main() {
  late DateTime now;

  Future<ProviderContainer> pumpSignedIn(WidgetTester tester) async {
    now = DateTime.utc(2026, 10, 15, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SavingsSession.new),
          inactivityClockProvider.overrideWithValue(() => now),
        ],
        child: AuthFlowListener(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            initialRoute: 'private',
            builder: (_, child) => InactivityGuard(child: child!),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(
                  [
                    settings.name,
                    (settings.arguments as AppRouteArguments?)?.message,
                  ].whereType<String>().join(' '),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  Future<void> idle(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('warns at 2:00 idle and signs out at 3:00', (tester) async {
    final container = await pumpSignedIn(tester);

    await idle(tester, const Duration(minutes: 1, seconds: 59));
    expect(find.text('Stay signed in'), findsNothing);
    await idle(tester, const Duration(seconds: 1));
    expect(find.text('Stay signed in'), findsOneWidget);

    await idle(tester, const Duration(minutes: 1));
    expect(container.read(authSessionProvider), isNull);
    expect(find.text('Stay signed in'), findsNothing);
    expect(find.text(_signedOut), findsOneWidget);
  });

  testWidgets('Stay signed in starts a full new period', (tester) async {
    final container = await pumpSignedIn(tester);
    await idle(tester, const Duration(minutes: 2, seconds: 30));

    await tester.tap(find.text('Stay signed in'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stay signed in'), findsNothing);

    // Past the original 3:00 deadline, but inside the new period.
    await idle(tester, const Duration(minutes: 1, seconds: 59));
    expect(container.read(authSessionProvider), isNotNull);
    expect(find.text('Stay signed in'), findsNothing);
    expect(find.text('private'), findsOneWidget);
  });

  testWidgets('resuming after 3:00 in background signs out before private '
      'content shows', (tester) async {
    final container = await pumpSignedIn(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await idle(tester, const Duration(minutes: 3));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('private'), findsNothing);
    expect(find.text('Stay signed in'), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(authSessionProvider), isNull);
    expect(find.text(_signedOut), findsOneWidget);
  });
}
