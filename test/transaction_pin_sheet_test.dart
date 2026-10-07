import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/transaction_pin_sheet.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/transaction_authorizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = TransactionSummary(
  title: 'Send to Ada Obi',
  amountDisplay: '₦1,000.00',
  lines: [('To', 'ADA OBI'), ('Bank', 'Zenith')],
);

/// Opens the PIN sheet from a button and records what it returns.
Future<List<String?>> _open(WidgetTester tester, {String? error}) async {
  final results = <String?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: CheetahTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await collectCoreTransactionPin(
                context,
                _summary,
                errorMessage: error,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return results;
}

/// The PIN field's cursor blinks forever, so `pumpAndSettle` never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder get _pinInput => find.byType(EditableText).first;
Finder get _confirm => find.widgetWithText(FilledButton, 'Confirm transfer');

void main() {
  testWidgets('shows what is being authorized', (tester) async {
    await _open(tester);
    expect(find.text('₦1,000.00'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
    expect(find.text('Zenith'), findsOneWidget);
  });

  testWidgets('fewer than four digits cannot continue', (tester) async {
    final results = await _open(tester);
    await tester.enterText(_pinInput, '000');
    await tester.pump();
    await tester.tap(_confirm, warnIfMissed: false);
    await _settle(tester);
    expect(results, isEmpty);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsOneWidget);
  });

  testWidgets('returns a leading-zero PIN unchanged', (tester) async {
    final results = await _open(tester);
    await tester.enterText(_pinInput, '0007');
    await tester.pump();
    await tester.tap(_confirm);
    await _settle(tester);
    expect(results, ['0007']);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsNothing);
  });

  testWidgets('cancel returns null', (tester) async {
    final results = await _open(tester);
    await tester.enterText(_pinInput, '12');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(results, [null]);
  });

  testWidgets('input is obscured', (tester) async {
    await _open(tester);
    await tester.enterText(_pinInput, '4321');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<EditableText>(_pinInput).obscureText, isTrue);
    // No visible cell renders a typed digit.
    for (final digit in ['4', '3', '2', '1', '4321']) {
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == digit),
        findsNothing,
      );
    }
  });

  testWidgets('the entry is emptied when the sheet closes', (tester) async {
    await _open(tester);
    await tester.enterText(_pinInput, '0007');
    await tester.pump();
    final controller = tester.widget<EditableText>(_pinInput).controller;
    await tester.tap(_confirm);
    await tester.pump();
    expect(controller.text, isEmpty);
    await _settle(tester);
  });

  testWidgets('shows a safe error passed back by the caller', (tester) async {
    await _open(tester, error: 'That PIN was not accepted.');
    expect(find.text('That PIN was not accepted.'), findsOneWidget);
  });
}
