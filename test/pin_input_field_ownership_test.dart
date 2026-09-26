import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/component/text_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/responsive_fixtures.dart';

void main() {
  testWidgets(
    'PinInputField leaves a caller-owned controller usable after the field '
    'unmounts',
    (tester) async {
      // Non-empty on purpose: ValueNotifier.value= short-circuits when the
      // value is unchanged, so clear() on an empty disposed controller stays
      // silent. Only a real mutation reaches debugAssertNotDisposed.
      final controller = TextEditingController(text: '1234');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinInputField(pinLength: 4, pinCtrl: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 350));

      controller.clear();
      expect(controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PinInputField owns and disposes its controller when the caller supplies '
    'none',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PinInputField(pinLength: 4))),
      );
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(EditableText).first, '12');
      await tester.pump(const Duration(milliseconds: 350));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Forgot transaction PIN survives a prior Change PIN dialog', (
    tester,
  ) async {
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
    await tester.pump(const Duration(milliseconds: 350));

    await tester.scrollUntilVisible(
      find.text('Transaction PIN'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Transaction PIN'));
    await tester.pump(const Duration(milliseconds: 350));

    // Leave text behind in _confirmPinController: an empty controller cannot
    // reproduce the crash, because ValueNotifier.value= short-circuits when
    // the value does not change.
    await tester.enterText(find.byType(EditableText).last, '9');
    await tester.pump(const Duration(milliseconds: 350));
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.scrollUntilVisible(
      find.text('Forgot transaction PIN'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Forgot transaction PIN'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    expect(find.text('Reset transaction PIN'), findsOneWidget);
  });
}
