import 'dart:async';

import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('retry action stays disabled until its request completes', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Scaffold(
          body: ApiStateCard(
            title: 'Unavailable',
            message: 'Try again.',
            tone: ApiStateTone.error,
            actionLabel: 'Retry',
            onAction: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('shared buttons show and announce loading ($dark)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? CheetahTheme.darkTheme : CheetahTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                PrimaryButton(
                  label: 'Save',
                  isLoading: true,
                  onPressed: () => taps++,
                ),
                SecondaryButton(
                  label: 'Check status',
                  isLoading: true,
                  onPressed: () => taps++,
                ),
                BocTextButton(
                  label: 'Resend code',
                  isLoading: true,
                  onPressed: () => taps++,
                ),
                DestructiveButton(
                  label: 'Delete account',
                  isLoading: true,
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNWidgets(4));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      expect(taps, 0);
    });
  }
}
