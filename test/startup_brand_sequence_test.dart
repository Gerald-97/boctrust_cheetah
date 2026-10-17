import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/startup_brand_sequence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(390, 844);
final _centre = Offset(_screen.width / 2, _screen.height / 2);

Future<void> _pump(WidgetTester tester, {required bool reduceMotion}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: CheetahTheme.lightTheme,
      home: StartupBrandSequence(reduceMotion: reduceMotion),
    ),
  );
}

Rect _mark(WidgetTester tester) => tester.getRect(find.byType(BocBrandMark));

double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('reveals the words after the mark settles in place', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: false);
    expect(_mark(tester).size, const Size(120, 120));
    expect(_mark(tester).center, _centre);
    expect(_opacity(tester, 'Cheetah'), 0);
    expect(_opacity(tester, 'by BocTrust'), 0);

    await tester.pump(const Duration(milliseconds: 325));
    expect(_mark(tester).width, greaterThan(120));
    expect(_mark(tester).center, _centre);
    expect(_opacity(tester, 'Cheetah'), 0);

    await tester.pump(const Duration(milliseconds: 425)); // 750 ms
    expect(_opacity(tester, 'Cheetah'), inExclusiveRange(0, 1));
    expect(_opacity(tester, 'by BocTrust'), 0);

    await tester.pump(const Duration(milliseconds: 350)); // 1100 ms
    expect(_opacity(tester, 'Cheetah'), 1);
    expect(_opacity(tester, 'by BocTrust'), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 250)); // 1350 ms
    expect(_opacity(tester, 'by BocTrust'), 1);
    expect(
      _mark(tester),
      Rect.fromCenter(center: _centre, width: 120, height: 120),
    );
  });

  testWidgets('reduced motion shows the final composition at once', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: true);
    expect(_opacity(tester, 'Cheetah'), 1);
    expect(_opacity(tester, 'by BocTrust'), 1);
    expect(
      _mark(tester),
      Rect.fromCenter(center: _centre, width: 120, height: 120),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.text('Licensed by the CBN · Deposits insured by the NDIC'),
      findsOneWidget,
    );
  });

  testWidgets('names the lockup once, in navy', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, reduceMotion: true);
    expect(find.bySemanticsLabel('Cheetah by BocTrust'), findsOneWidget);
    for (final text in ['Cheetah', 'by BocTrust']) {
      expect(tester.widget<Text>(find.text(text)).style?.color, BocColors.navy);
    }
    handle.dispose();
  });
}
