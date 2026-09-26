import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/responsive_fixtures.dart';

Future<void> _pumpAccount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        userProfileProvider.overrideWith(LayoutProfile.new),
      ],
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: const AppFlowNavigator(initialScreen: AppScreen.securityCenter),
      ),
    ),
  );
  await _settle(tester);
}

/// Pumps a bounded number of frames instead of `pumpAndSettle`, which never
/// returns while a `PinCodeTextField` cursor animation is on screen.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _openSetting(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(label));
  await _settle(tester);
}

Widget _host(ThemeData theme, Widget child, {double textScale = 1}) =>
    MaterialApp(
      theme: theme,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: inner!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  for (final (name, theme) in [
    ('light', CheetahTheme.lightTheme),
    ('dark', CheetahTheme.darkTheme),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('AppActionSheet renders in $name at scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var tapped = 0;
        await tester.pumpWidget(
          _host(
            theme,
            AppActionSheet(
              icon: Icons.verified_user_outlined,
              title: 'Security check',
              subtitle: 'Choose how you want to verify that it is you.',
              child: AppActionSheetOption(
                icon: Icons.password_rounded,
                title: 'Verify current password',
                subtitle: 'Use your account sign-in password',
                onTap: () => tapped++,
              ),
            ),
            textScale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('app-action-sheet')), findsOneWidget);
        expect(find.text('Security check'), findsOneWidget);
        expect(find.text('Verify current password'), findsOneWidget);

        final material = tester.widget<Material>(
          find.byKey(const Key('app-action-sheet')),
        );
        expect(material.color, theme.cardColor);

        await tester.tap(find.text('Verify current password'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tapped, 1);
      });
    }
  }

  testWidgets('Security checks opens the branded chooser', (tester) async {
    await _pumpAccount(tester);
    await _openSetting(tester, 'Security checks');

    expect(find.byKey(const Key('app-action-sheet')), findsOneWidget);
    expect(find.byKey(const Key('security-password-option')), findsOneWidget);
    expect(find.byKey(const Key('security-pin-option')), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('Forgot transaction PIN opens recovery, not the chooser', (
    tester,
  ) async {
    await _pumpAccount(tester);
    await _openSetting(tester, 'Forgot transaction PIN');

    expect(find.text('Reset transaction PIN'), findsOneWidget);
    expect(find.byKey(const Key('security-password-option')), findsNothing);
    expect(find.byKey(const Key('security-pin-option')), findsNothing);
  });

  testWidgets('Choosing PIN opens the current-PIN dialog', (tester) async {
    await _pumpAccount(tester);
    await _openSetting(tester, 'Security checks');

    await tester.tap(find.byKey(const Key('security-pin-option')));
    await _settle(tester);

    expect(find.byKey(const Key('app-action-sheet')), findsNothing);
    expect(find.text('Verify current PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dismissing the chooser opens no dialog', (tester) async {
    await _pumpAccount(tester);
    await _openSetting(tester, 'Security checks');

    Navigator.of(
      tester.element(find.byKey(const Key('app-action-sheet'))),
    ).pop();
    await _settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recovery sheet uses the branded shell', (tester) async {
    await _pumpAccount(tester);
    await _openSetting(tester, 'Forgot transaction PIN');

    expect(find.byKey(const Key('app-action-sheet')), findsOneWidget);
    expect(find.text('Reset transaction PIN'), findsOneWidget);
    expect(
      find.text("We'll send a code to verify your account."),
      findsOneWidget,
    );
    expect(find.text('Send code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
