import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/responsive_fixtures.dart';

/// Raises and lowers the keyboard inset at runtime.
///
/// The responsive suite sets `viewInsets` once per scenario, so it renders each
/// layout branch but never crosses between them. Focus is only destroyed by the
/// transition, which is why a statically-sized test cannot catch it.
class _KeyboardHarness extends StatefulWidget {
  const _KeyboardHarness({required this.screen});

  final AppScreen screen;

  static _KeyboardHarnessState of(WidgetTester tester) =>
      tester.state(find.byType(_KeyboardHarness));

  @override
  State<_KeyboardHarness> createState() => _KeyboardHarnessState();
}

class _KeyboardHarnessState extends State<_KeyboardHarness> {
  double _bottomInset = 0;

  void showKeyboard() => setState(() => _bottomInset = 336);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: CheetahTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(viewInsets: EdgeInsets.only(bottom: _bottomInset)),
      child: child!,
    ),
    home: AppFlowNavigator(initialScreen: widget.screen),
  );
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, AppScreen screen) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://keyboard-test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 503,
            data: {'message': 'Unavailable in keyboard test'},
          ),
        ),
      ),
    );
    addTearDown(dio.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dioProvider.overrideWithValue(dio),
          startupGateProvider.overrideWith(LayoutStartup.new),
        ],
        child: _KeyboardHarness(screen: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Every screen built on the auth shell, which switches its footer between
  // pinned and scrolling depending on available height.
  for (final screen in [
    AppScreen.login,
    AppScreen.createPassword,
    AppScreen.otp,
  ]) {
    testWidgets('$screen keeps focus when the keyboard opens', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpScreen(tester, screen);

      final field = find.byType(EditableText).first;
      expect(
        field,
        findsOneWidget,
        reason: 'the screen must have a field to focus',
      );

      await tester.tap(field, warnIfMissed: false);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(
        focused?.hasFocus,
        isTrue,
        reason: 'tapping the field must focus it',
      );

      // The keyboard now animates in, which is what previously swapped the
      // layout to a structurally different tree and discarded focus.
      _KeyboardHarness.of(tester).showKeyboard();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        FocusManager.instance.primaryFocus,
        same(focused),
        reason:
            'the keyboard opening must not rebuild the field under a different '
            'parent chain; losing focus here dismisses the keyboard before a '
            'character can be typed',
      );
      expect(tester.takeException(), isNull);
    });
  }

  // The focus loss itself needs a real IME and does not reproduce under
  // flutter_test, so this asserts the property that caused it instead: the
  // widget tree above the fields must not change shape when the keyboard
  // opens. Re-parenting the fields is what disposes their FormFieldState and
  // closes the input connection on device.
  testWidgets('the ancestor chain above the fields survives the keyboard', (
    tester,
  ) async {
    // Deliberately short. Scaffold consumes viewInsets for its body, so the
    // shell's `maxHeight < 480` test is what actually flips on a handset once
    // the keyboard takes roughly 40% of the screen. A taller viewport never
    // crosses the threshold and the regression hides.
    tester.view.physicalSize = const Size(412, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<String> chainAboveField() {
      final element = tester.element(find.byType(EditableText).first);
      final chain = <String>[];
      element.visitAncestorElements((ancestor) {
        chain.add(ancestor.widget.runtimeType.toString());
        return chain.length < 25;
      });
      return chain;
    }

    await pumpScreen(tester, AppScreen.login);
    final closed = chainAboveField();

    _KeyboardHarness.of(tester).showKeyboard();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final open = chainAboveField();

    expect(
      open,
      equals(closed),
      reason:
          'the keyboard must not re-parent the fields; a different ancestor '
          'chain rebuilds each TextFormField, disposing the focus node it owns '
          'and dismissing the keyboard before a character can be typed',
    );
  });

  testWidgets('the auth footer stays reachable once the keyboard is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(tester, AppScreen.login);
    _KeyboardHarness.of(tester).showKeyboard();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The footer moves into the scroll view rather than being pinned, so it
    // must still be scrollable into view rather than clipped away.
    final button = find.byType(FilledButton).first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
