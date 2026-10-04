import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/component/text_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(
        rootBundle.load('assets/font/PlusJakartaSans-$weight.ttf'),
      );
    }
    await loader.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    for (final label in [
      'Forgot transaction PIN',
      'Transaction PIN',
      'Password',
      'Security checks',
      'Email verification',
    ]) {
      testWidgets('$label sheet with large text and keyboard at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              userProfileProvider.overrideWith(LayoutProfile.new),
            ],
            child: MaterialApp(
              theme: CheetahTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: appHome(
                route: label == 'Email verification'
                    ? AppRoutes.myProfile
                    : AppRoutes.securitySettings,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(label),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        final modal = find.byType(BottomSheet).evaluate().isNotEmpty
            ? find.byType(BottomSheet)
            : find.byType(AlertDialog);
        final fields = find.descendant(
          of: modal,
          matching: find.byType(EditableText),
        );
        if (fields.evaluate().isNotEmpty) {
          final pins = find.descendant(
            of: modal,
            matching: find.byType(PinInputField),
          );
          final target = pins.evaluate().isNotEmpty ? pins.first : fields.first;
          await tester.ensureVisible(target);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.tap(target);
          tester.view.viewInsets = FakeViewPadding(bottom: size.height * .4);
          await tester.pump(const Duration(milliseconds: 350));
          expect(tester.takeException(), isNull);
        }
        Navigator.of(tester.element(modal)).pop();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        // Reopening catches child widgets that accidentally disposed parent controllers.
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pump();
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(modal)).pop();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'PIN inputs rebind stages and preserve caller-owned controllers',
    (tester) async {
      final otp = TextEditingController();
      final pin = TextEditingController();
      final focus = FocusNode();
      addTearDown(otp.dispose);
      addTearDown(pin.dispose);
      addTearDown(focus.dispose);
      Widget field(TextEditingController controller, int length) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: PinInputField(
                pinCtrl: controller,
                pinLength: length,
                focusNode: focus,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(field(otp, 6));
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpWidget(field(pin, 4));
      await tester.enterText(find.byType(EditableText), '5839');
      expect(pin.text, '5839');
      expect(otp.text, '123456');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(() {
        otp.clear();
        pin.clear();
        focus.requestFocus();
      }, returnsNormally);
    },
  );
}
