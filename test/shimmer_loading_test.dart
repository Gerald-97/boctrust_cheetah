import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (theme, dark) in [
    (CheetahTheme.lightTheme, false),
    (CheetahTheme.darkTheme, true),
  ]) {
    testWidgets('loading block shimmers with theme colors ($dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: AppShimmerBlock(width: 160, height: 20)),
        ),
      );

      final block = find.byType(AppShimmerBlock);
      expect(block, findsOneWidget);
      final first = tester.widget<DecoratedBox>(
        find.descendant(of: block, matching: find.byType(DecoratedBox)),
      );
      final firstGradient = (first.decoration as BoxDecoration).gradient!;
      expect(firstGradient.colors, hasLength(3));
      expect(firstGradient.colors.first, isNot(firstGradient.colors[1]));
      await tester.pump(const Duration(milliseconds: 400));
      final second = tester.widget<DecoratedBox>(
        find.descendant(of: block, matching: find.byType(DecoratedBox)),
      );
      expect(
        (second.decoration as BoxDecoration).gradient,
        isNot(firstGradient),
      );
    });
  }
}
