import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _navy = Color(0xFF1A2A3C);

Future<void> _pumpNav(
  WidgetTester tester, {
  ThemeData? theme,
  AppSection selected = AppSection.send,
  ValueChanged<AppSection>? onSelected,
  Size size = const Size(430, 932),
}) async {
  tester.view.physicalSize = size;
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

double _contrastRatio(Color a, Color b) {
  final brighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(brighter, a) ? b : a;
  return (brighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Future<void> _pumpScaffoldList(
  WidgetTester tester, {
  ValueChanged<int>? onRow,
  ValueChanged<AppSection>? onSection,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CheetahTheme.lightTheme,
      home: Builder(
        builder: (context) => AppScaffold(
          activeSection: AppSection.home,
          onSectionSelected: onSection ?? (_) {},
          body: ListView(
            padding: EdgeInsets.zero.clearOfNav(context),
            children: [
              for (var i = 0; i < 30; i++)
                InkWell(
                  onTap: () => onRow?.call(i),
                  child: SizedBox(height: 60, child: Text('Row $i')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Finder _pill() => find.byKey(AppBottomNavigation.pillKey);

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
    expect(_filterOf(tester, 'home_linear'), _tint(const Color(0xFF5C636C)));
    expect(_labelStyle(tester, 'Home')?.color, const Color(0xFF5C636C));
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

  group('floats above content with a distinct edge', () {
    testWidgets('light', (tester) async {
      final theme = CheetahTheme.lightTheme;
      await _pumpNav(tester, theme: theme);
      expect(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      final pill = _pill();
      expect(pill, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(pill).decoration as BoxDecoration;
      final surface = theme.extension<BocSemanticColors>()!.surface;
      expect(decoration.color, surface);
      expect(decoration.border, isNotNull);
      expect(
        _contrastRatio((decoration.border! as Border).top.color, surface),
        greaterThan(1.8),
      );
      final rect = tester.getRect(pill);
      expect(rect.width, 350);
      expect(rect.center.dx, 215);
    });

    testWidgets('dark', (tester) async {
      final theme = CheetahTheme.darkTheme;
      await _pumpNav(tester, theme: theme);
      final decoration =
          tester.widget<DecoratedBox>(_pill()).decoration as BoxDecoration;
      final surface = theme.extension<BocSemanticColors>()!.surface;
      expect(decoration.color, surface);
      expect(decoration.border, isNotNull);
      expect(
        _contrastRatio((decoration.border! as Border).top.color, surface),
        greaterThan(1.8),
      );
    });

    testWidgets('AppScaffold lets content flow under the pill', (tester) async {
      await _pumpScaffoldList(tester);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
      // The list's viewport runs to the bottom of the screen, behind the pill.
      expect(tester.getRect(find.byType(Scrollable)).bottom, 932);
      // Scrolled to the end, the last row clears the pill.
      final state = tester.state<ScrollableState>(find.byType(Scrollable));
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getRect(find.text('Row 29')).bottom,
        lessThanOrEqualTo(tester.getRect(_pill()).top),
      );
    });

    testWidgets('taps beside the pill reach the page, taps on it do not', (
      tester,
    ) async {
      final rows = <int>[];
      AppSection? section;
      await _pumpScaffoldList(
        tester,
        onRow: rows.add,
        onSection: (s) => section = s,
      );
      final pill = tester.getRect(_pill());
      // Beside the pill, the row scrolled behind it takes the tap.
      await tester.tapAt(Offset(pill.left / 2, pill.center.dy));
      expect(rows, hasLength(1));
      // On the pill, the nav takes it and the row behind does not.
      await tester.tapAt(tester.getCenter(find.text('Account')));
      expect(section, AppSection.account);
      expect(rows, hasLength(1));
    });

    testWidgets('clearOfNav adds the pill footprint and safe-area inset', (
      tester,
    ) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Builder(
            builder: (context) {
              padding = const EdgeInsets.all(16).clearOfNav(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(padding, const EdgeInsets.fromLTRB(16, 16, 16, 16 + 73 + 8 + 34));
    });
  });

  for (final (width, scale) in [(320.0, 1.0), (375.0, 1.3), (375.0, 2.0)]) {
    testWidgets('labels are not truncated at ${width}px, ${scale}x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpNav(tester, size: Size(width, 800));
      for (final label in ['Home', 'Save', 'Send', 'Pay', 'Account']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
    });
  }

  testWidgets('dark pill shadow is dark, not a light halo', (tester) async {
    await _pumpNav(tester, theme: CheetahTheme.darkTheme);
    final shadowed = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).boxShadow != null,
    );
    final shadows =
        (tester.widget<DecoratedBox>(shadowed).decoration as BoxDecoration)
            .boxShadow!;
    expect(shadows, hasLength(2));
    expect(
      shadows.every((shadow) => shadow.color.computeLuminance() < 0.05),
      isTrue,
    );
  });

  testWidgets('ripples paint on the pill, not under it', (tester) async {
    await _pumpNav(tester);
    final material = find
        .ancestor(
          of: find.byType(InkWell).first,
          matching: find.byType(Material),
        )
        .first;
    expect(find.descendant(of: _pill(), matching: material), findsOneWidget);
  });

  testWidgets('the full pill height is tappable', (tester) async {
    AppSection? tapped;
    await _pumpNav(tester, onSelected: (s) => tapped = s);
    final pill = tester.getRect(_pill());
    final account = tester.getCenter(find.text('Account'));
    await tester.tapAt(Offset(account.dx, pill.top + 3));
    expect(tapped, AppSection.account);
    tapped = null;
    await tester.tapAt(Offset(account.dx, pill.bottom - 3));
    expect(tapped, AppSection.account);
  });
}
