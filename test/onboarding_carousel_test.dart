import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/startup_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

const _slides = [
  (
    'Save without thinking about it',
    'Boc Flex Savings grows every day',
    'save',
  ),
  (
    'Reach any goal, your way',
    'Save toward a goal, lock in a fixed term',
    'goals',
  ),
  (
    'Send and pay, instantly',
    'Move money between your BOCTRUST accounts',
    'pay',
  ),
];

void main() {
  testWidgets('the carousel walks save, goals and pay then starts sign-up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();
    final container = ProviderContainer(overrides: await flowTestOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          darkTheme: CheetahTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const OnboardingScreen(),
        ),
      ),
    );

    expect(find.text('Skip'), findsNothing);
    expect(find.byType(CheetahBrand), findsNothing);
    expect(find.byType(RegulatoryBadge), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      BocColors.paper,
    );

    // Swiping slides the art and its copy follows once it settles.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(_slides[1].$1), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/img/onboarding/goals-still.png')),
      findsOneWidget,
    );
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(_slides[0].$1), findsOneWidget);

    for (final (i, (title, description, name)) in _slides.indexed) {
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining(description), findsOneWidget);
      expect(
        find.image(AssetImage('assets/img/onboarding/$name-still.png')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Slide ${i + 1} of 3'), findsOneWidget);
      if (i < 2) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('Next'), findsNothing);

    // Dots jump straight to a slide.
    await tester.tap(find.bySemanticsLabel('Slide 1 of 3'));
    await tester.pumpAndSettle();
    expect(find.text(_slides[0].$1), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Slide 3 of 3'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(
      container.read(authNavigationProvider).single.destination,
      AuthDestination.verificationMethod,
    );

    await tester.tap(find.text('I already have an account'));
    await tester.pump();
    final intent = container.read(authNavigationProvider).last;
    expect(intent.destination, AuthDestination.login);
    expect(intent.mode, AuthNavigationMode.clearStack);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
