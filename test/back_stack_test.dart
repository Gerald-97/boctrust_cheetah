import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/screens/account_screens.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/home/screens/home_screen.dart';
import 'package:boctrust_savings_loan/module/notifications/screens/notifications_screen.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/payments/screens/payments_screens.dart';
import 'package:boctrust_savings_loan/module/savings/screens/savings_screens.dart';
import 'package:boctrust_savings_loan/module/send/screens/send_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

/// Back-stack parity for the routed screens that replaced the flow
/// navigator's in-place history.
void main() {
  late ProviderContainer container;

  /// Opens [route] as the only page, signed in with a created PIN.
  Future<void> openAlone(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        ...await flowTestOverrides(),
        authSessionProvider.overrideWith(SavingsSession.new),
        userProfileProvider.overrideWith(LayoutProfile.new),
        userHomeProvider.overrideWith(LayoutHome.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: (_) => [
            AppRouter.onGenerateRoute(RouteSettings(name: route)),
          ],
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  testWidgets('a pushed page returns to Home on Back', (tester) async {
    await openAlone(tester, AppRoutes.home);
    await tester.tap(find.byTooltip('Notifications'));
    await settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await systemBack(tester);
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a Home quick action pushes, so Back returns to Home', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.home);
    final send = find.widgetWithText(QuickAction, 'Send');
    await tester.tap(send);
    await settle(tester);
    expect(find.byType(SendScreen), findsOneWidget);

    await systemBack(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the Save tab replaces Home, and Back from it returns Home', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.home);
    await tapTab(tester, 'Save');
    expect(find.byType(SaveHubScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await systemBack(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SaveHubScreen), findsNothing);
  });

  for (final (label, hubType) in [
    ('Send', SendScreen),
    ('Pay', PaymentsScreen),
    ('Account', AccountScreen),
  ]) {
    testWidgets('$label tab returns Home on system Back', (tester) async {
      await openAlone(tester, AppRoutes.home);
      await tapTab(tester, label);
      expect(find.byType(hubType), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(hubType), findsNothing);
    });
  }

  testWidgets('a tab switch uses the gentler section transition', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.home);
    await tester.tap(find.text('Account').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('a lone savings page falls back to the Savings hub', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.flexSave);
    expect(find.byType(FlexScreen), findsOneWidget);

    await systemBack(tester);
    expect(find.byType(SaveHubScreen), findsOneWidget);
  });

  testWidgets('a lone unavailable savings page falls back to the hub', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.flexWithdraw);
    expect(find.text('Withdrawals are not available yet.'), findsOneWidget);

    await systemBack(tester);
    expect(find.byType(SaveHubScreen), findsOneWidget);
  });

  group('Back to Savings', () {
    NavigatorState navigatorOf(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator));

    Future<void> tapBackToSavings(WidgetTester tester) async {
      final button = find.text('Back to Savings');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle(tester);
    }

    testWidgets('pops to the hub beneath instead of stacking one', (
      tester,
    ) async {
      await openAlone(tester, AppRoutes.savingsHub);
      navigatorOf(tester).pushNamed(AppRoutes.flexSave);
      await settle(tester);
      navigatorOf(tester).pushNamed(AppRoutes.flexWithdraw);
      await settle(tester);

      await tapBackToSavings(tester);

      expect(find.byType(SaveHubScreen), findsOneWidget);
      expect(find.byType(FlexScreen, skipOffstage: false), findsNothing);
      expect(navigatorOf(tester).canPop(), isFalse);
    });

    testWidgets('replaces a lone unavailable page with the hub', (
      tester,
    ) async {
      await openAlone(tester, AppRoutes.flexWithdraw);

      await tapBackToSavings(tester);

      expect(find.byType(SaveHubScreen), findsOneWidget);
      expect(navigatorOf(tester).canPop(), isFalse);
    });

    testWidgets('keeps Home beneath when no hub is open', (tester) async {
      await openAlone(tester, AppRoutes.home);
      navigatorOf(tester).pushNamed(AppRoutes.flexWithdraw);
      await settle(tester);

      await tapBackToSavings(tester);
      expect(find.byType(SaveHubScreen), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('a deep-linked account page stays on system Back', (
    tester,
  ) async {
    await openAlone(tester, AppRoutes.securitySettings);
    await systemBack(tester);
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  group('auth screens with a cleared stack fall back', () {
    for (final (route, destination) in [
      (AppRoutes.verificationMethod, AuthDestination.login),
      (AppRoutes.passwordReset, AuthDestination.login),
      (AppRoutes.otp, AuthDestination.verificationMethod),
      (AppRoutes.createPassword, AuthDestination.verificationMethod),
    ]) {
      testWidgets('$route → $destination', (tester) async {
        await openAlone(tester, route);
        await systemBack(tester);
        final intents = container.read(authNavigationProvider);
        expect(intents, isNotEmpty);
        expect(intents.last.destination, destination);
        expect(intents.last.mode, AuthNavigationMode.clearStack);
      });
    }
  });
}

/// Lets route transitions and the access gate finish without waiting on
/// spinners that never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
