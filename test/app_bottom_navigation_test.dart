import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _navy = Color(0xFF1A2A3C);

Future<void> _pumpNav(
  WidgetTester tester, {
  ThemeData? theme,
  AppSection selected = AppSection.send,
  ValueChanged<AppSection>? onSelected,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CheetahTheme.lightTheme,
      home: Scaffold(
        bottomNavigationBar: AppBottomNavigation(
          selected: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
}

Finder _navIcon(String asset) => find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      w.bytesLoader is SvgAssetLoader &&
      (w.bytesLoader as SvgAssetLoader).assetName ==
          'assets/svg/nav/$asset.svg',
);

ColorFilter? _filterOf(WidgetTester tester, String asset) =>
    tester.widget<SvgPicture>(_navIcon(asset)).colorFilter;

TextStyle? _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style;

ColorFilter _tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

Finder _pill() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color != null &&
      (w.decoration as BoxDecoration).borderRadius ==
          BorderRadius.circular(BocRadius.pill),
);

void main() {
  testWidgets('send tab shows send-2 icons', (tester) async {
    await _pumpNav(tester);
    expect(_navIcon('send_bold'), findsOneWidget);
    expect(_navIcon('send_linear'), findsNothing);
    for (final tab in ['home', 'save', 'pay', 'account']) {
      expect(_navIcon('${tab}_linear'), findsOneWidget, reason: tab);
      expect(_navIcon('${tab}_bold'), findsNothing, reason: tab);
    }
    expect(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('light theme colours', (tester) async {
    await _pumpNav(tester, theme: CheetahTheme.lightTheme);
    expect(_filterOf(tester, 'send_bold'), _tint(_navy));
    expect(_labelStyle(tester, 'Send')?.color, _navy);
    expect(_labelStyle(tester, 'Send')?.fontWeight, FontWeight.w700);
    expect(_filterOf(tester, 'home_linear'), _tint(const Color(0xFF8995A2)));
    expect(_labelStyle(tester, 'Home')?.color, const Color(0xFF8995A2));
    expect(_labelStyle(tester, 'Home')?.fontWeight, FontWeight.w600);
  });

  testWidgets('dark theme colours', (tester) async {
    await _pumpNav(tester, theme: CheetahTheme.darkTheme);
    expect(_filterOf(tester, 'send_bold'), _tint(const Color(0xFFECEFF3)));
    expect(_labelStyle(tester, 'Send')?.color, const Color(0xFFECEFF3));
    expect(_filterOf(tester, 'home_linear'), _tint(const Color(0xFF93A2B4)));
    expect(_labelStyle(tester, 'Home')?.color, const Color(0xFF93A2B4));
  });

  for (final brightness in Brightness.values) {
    testWidgets('high contrast inactive uses textTertiary ($brightness)', (
      tester,
    ) async {
      final theme = CheetahTheme.theme(brightness, highContrast: true);
      await _pumpNav(tester, theme: theme);
      final tertiary = theme.extension<BocSemanticColors>()!.textTertiary;
      expect(_filterOf(tester, 'home_linear'), _tint(tertiary));
      expect(_labelStyle(tester, 'Home')?.color, tertiary);
    });
  }

  testWidgets('tapping Account calls onSelected', (tester) async {
    final handle = tester.ensureSemantics();
    AppSection? tapped;
    await _pumpNav(tester, onSelected: (s) => tapped = s);
    await tester.tap(find.text('Account'));
    expect(tapped, AppSection.account);
    expect(find.bySemanticsLabel('Send'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Send')),
      matchesSemantics(
        label: 'Send',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  group('floats as a translucent pill', () {
    testWidgets('light', (tester) async {
      await _pumpNav(tester, theme: CheetahTheme.lightTheme);
      expect(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      final pill = _pill();
      expect(pill, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(pill).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xCCFFFFFF));
      final rect = tester.getRect(pill);
      expect(rect.width, 350);
      expect(rect.center.dx, 215);
    });

    testWidgets('dark', (tester) async {
      final theme = CheetahTheme.darkTheme;
      await _pumpNav(tester, theme: theme);
      final decoration =
          tester.widget<DecoratedBox>(_pill()).decoration as BoxDecoration;
      expect(
        decoration.color,
        theme.extension<BocSemanticColors>()!.surface.withValues(alpha: 0.8),
      );
    });

    testWidgets('AppScaffold extends its body behind the pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: AppScaffold(
            body: const SizedBox(),
            activeSection: AppSection.home,
            onSectionSelected: (_) {},
          ),
        ),
      );
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    });
  });
}
