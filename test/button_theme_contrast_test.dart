import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilledButton theme contrast', () {
    final themes = <String, ThemeData>{
      'light': CheetahTheme.lightTheme,
      'dark': CheetahTheme.darkTheme,
      'high contrast light': CheetahTheme.theme(
        Brightness.light,
        highContrast: true,
      ),
      'high contrast dark': CheetahTheme.theme(
        Brightness.dark,
        highContrast: true,
      ),
    };

    for (final entry in themes.entries) {
      test('${entry.key} disabled button text meets WCAG AA', () {
        final theme = entry.value;
        final style = theme.filledButtonTheme.style!;
        final disabledStates = <WidgetState>{WidgetState.disabled};
        final background = style.backgroundColor!.resolve(disabledStates)!;
        final foreground = style.foregroundColor!.resolve(disabledStates)!;

        for (final surface in <Color>{
          theme.scaffoldBackgroundColor,
          theme.cardColor,
        }) {
          final paintedBackground = Color.alphaBlend(background, surface);
          final paintedForeground = Color.alphaBlend(
            foreground,
            paintedBackground,
          );
          final ratio = _contrastRatio(paintedForeground, paintedBackground);

          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key} disabled FilledButton contrast was '
                '${ratio.toStringAsFixed(2)}:1 on ${surface.toARGB32()}',
          );
        }
      });
    }

    test('enabled brand colors remain unchanged', () {
      final lightStyle = CheetahTheme.lightTheme.filledButtonTheme.style!;
      final darkStyle = CheetahTheme.darkTheme.filledButtonTheme.style!;

      expect(lightStyle.backgroundColor!.resolve({}), BocColors.navy);
      expect(lightStyle.foregroundColor!.resolve({}), BocColors.goldLight);
      expect(darkStyle.backgroundColor!.resolve({}), BocColors.goldLight);
      expect(darkStyle.foregroundColor!.resolve({}), BocColors.navy);
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}
