import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/onboarding_slide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _gif = 'assets/img/onboarding/save.gif';
const _still = 'assets/img/onboarding/save-still.png';

Widget _app({
  String gifAsset = _gif,
  int index = 0,
  VoidCallback? onNext,
  VoidCallback? onLogin,
  ValueChanged<int>? onSelect,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: CheetahTheme.lightTheme,
  darkTheme: CheetahTheme.darkTheme,
  themeMode: ThemeMode.dark,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: Scaffold(
        body: OnboardingSlideView(
          gifAsset: gifAsset,
          stillAsset: _still,
          title: 'Save without thinking about it',
          description: 'Boc Flex Savings grows every day with no lock-in.',
          index: index,
          slideCount: 3,
          onNext: onNext ?? () {},
          onLogin: onLogin ?? () {},
          onSelect: onSelect ?? (_) {},
        ),
      ),
    ),
  ),
);

Finder _image(String asset) => find.image(AssetImage(asset));

void main() {
  testWidgets('lays out the slide with accessible actions', (tester) async {
    final handle = tester.ensureSemantics();
    var next = 0;
    var login = 0;
    int? selected;
    await tester.pumpWidget(
      _app(
        index: 1,
        onNext: () => next++,
        onLogin: () => login++,
        onSelect: (i) => selected = i,
      ),
    );

    final root = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(OnboardingSlideView),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(root.color, BocColors.paper);
    expect(find.byKey(OnboardingSlideView.arcsKey), findsOneWidget);
    final panel = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == BocColors.card &&
          (w.decoration as BoxDecoration).borderRadius ==
              const BorderRadius.vertical(top: Radius.circular(32)),
    );
    expect(panel, findsOneWidget);
    expect(find.text('Save without thinking about it'), findsOneWidget);
    expect(
      find.text('Boc Flex Savings grows every day with no lock-in.'),
      findsOneWidget,
    );

    for (var i = 0; i < 3; i++) {
      final dot = find.bySemanticsLabel('Slide ${i + 1} of 3');
      expect(dot, findsOneWidget);
      expect(
        tester.getSemantics(dot),
        matchesSemantics(
          label: 'Slide ${i + 1} of 3',
          isButton: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: i == 1,
        ),
      );
      final size = tester.getSize(dot);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }

    await tester.tap(find.bySemanticsLabel('Slide 3 of 3'));
    await tester.tap(find.byType(PrimaryButton));
    await tester.tap(find.text('I already have an account'));
    expect(selected, 2);
    expect(next, 1);
    expect(login, 1);
    handle.dispose();
  });

  testWidgets('shows the still until the GIF decodes or if it fails', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(_image(_still), findsOneWidget);

    await tester.pumpWidget(
      _app(gifAsset: 'assets/img/onboarding/missing.gif'),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_image(_still), findsOneWidget);
  });

  testWidgets('reduced motion shows only the still', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    expect(_image(_gif), findsNothing);
    expect(_image(_still), findsOneWidget);
  });

  testWidgets('fits small, large-text and tablet screens in dark mode', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    const cases = [
      (Size(320, 640), 1.0),
      (Size(320, 640), 2.0),
      (Size(768, 1024), 1.0),
    ];
    for (final (size, scale) in cases) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      tester.platformDispatcher
        ..textScaleFactorTestValue = scale
        ..platformBrightnessTestValue = Brightness.dark;
      var next = 0;
      var login = 0;
      await tester.pumpWidget(
        _app(onNext: () => next++, onLogin: () => login++),
      );
      expect(tester.takeException(), isNull, reason: '$size x$scale');

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have an account'));
      expect((next, login), (1, 1), reason: '$size x$scale');
    }
  });
}
