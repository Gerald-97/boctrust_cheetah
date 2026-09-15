import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

NativeDojahGateway _returning(String? result) =>
    NativeDojahGateway((widgetId, {required metadata}) async => result);

void main() {
  test(
    'sends the backend reference as metadata, not as a session resume',
    () async {
      final gateway = NativeDojahGateway((widgetId, {required metadata}) async {
        expect(widgetId, 'selfie-widget');
        expect(metadata, {'reference': 'boc-attempt-000001'});
        return 'pending';
      });

      await gateway.launch(
        widgetId: ' selfie-widget ',
        referenceId: ' boc-attempt-000001 ',
      );
    },
  );

  test('maps the SDK result tokens to capture outcomes', () async {
    const expected = {
      'approved': KycCaptureOutcome.submitted,
      'pending': KycCaptureOutcome.submitted,
      ' FAILED ': KycCaptureOutcome.failed,
      'closed': KycCaptureOutcome.cancelled,
    };
    for (final MapEntry(key: result, value: outcome) in expected.entries) {
      expect(
        await _returning(
          result,
        ).launch(widgetId: 'selfie-widget', referenceId: 'boc-attempt-000001'),
        outcome,
        reason: result,
      );
    }
  });

  test('anything else is unknown, never success', () async {
    // The plugin substitutes 'Verification Completed' for a null result and
    // reports caught native exceptions as successful replies.
    for (final result in [
      'Verification Completed',
      'approved!',
      'success',
      '',
      null,
    ]) {
      expect(
        await _returning(
          result,
        ).launch(widgetId: 'selfie-widget', referenceId: 'boc-attempt-000001'),
        KycCaptureOutcome.unknown,
        reason: result,
      );
    }
  });

  test('rejects missing launch configuration before native code', () async {
    var launched = false;
    final gateway = NativeDojahGateway((widgetId, {required metadata}) async {
      launched = true;
      return 'closed';
    });

    await expectLater(
      gateway.launch(widgetId: '', referenceId: 'boc-attempt-000001'),
      throwsFormatException,
    );
    await expectLater(
      gateway.launch(widgetId: 'selfie-widget', referenceId: ' '),
      throwsFormatException,
    );
    expect(launched, isFalse);
  });

  test('prevents concurrent native launches', () async {
    final first = Future<String>.delayed(
      const Duration(milliseconds: 20),
      () => 'closed',
    );
    final gateway = NativeDojahGateway(
      (widgetId, {required metadata}) => first,
    );

    final pending = gateway.launch(
      widgetId: 'selfie-widget',
      referenceId: 'boc-attempt-000001',
    );
    await expectLater(
      gateway.launch(
        widgetId: 'selfie-widget',
        referenceId: 'boc-attempt-000001',
      ),
      throwsStateError,
    );
    await pending;
  });
}
