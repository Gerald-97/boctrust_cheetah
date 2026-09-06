import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
