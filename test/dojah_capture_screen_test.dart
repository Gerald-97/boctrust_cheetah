import 'dart:async';

import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_capture_screen.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements DojahGateway {
  final result = Completer<KycCaptureOutcome>();
  var calls = 0;

  @override
  Future<KycCaptureOutcome> launch({
    required String widgetId,
    required String referenceId,
  }) {
    calls++;
    return result.future;
  }
}

void main() {
  testWidgets('launches once and returns the normalized outcome', (
    tester,
  ) async {
    final gateway = _Gateway();
    KycCaptureOutcome? outcome;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dojahGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<KycCaptureOutcome>(
                  MaterialPageRoute(
                    builder: (_) => const DojahCaptureScreen(
                      widgetId: 'selfie-widget',
                      referenceId: 'boc-attempt-000001',
                      operation: KycOperation.identity,
                    ),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(gateway.calls, 1);

    await tester.pump();
    expect(gateway.calls, 1);

    gateway.result.complete(KycCaptureOutcome.unknown);
    await tester.pumpAndSettle();
    expect(outcome, KycCaptureOutcome.unknown);
  });

  testWidgets('back is a cancellation while native capture is pending', (
    tester,
  ) async {
    final gateway = _Gateway();
    KycCaptureOutcome? outcome;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dojahGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<KycCaptureOutcome>(
                  MaterialPageRoute(
                    builder: (_) => const DojahCaptureScreen(
                      widgetId: 'government-widget',
                      referenceId: 'boc-attempt-000002',
                      operation: KycOperation.governmentId,
                    ),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(outcome, KycCaptureOutcome.cancelled);
  });
}
