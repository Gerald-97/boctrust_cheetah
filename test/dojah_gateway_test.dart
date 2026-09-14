import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the selected widget and backend reference', () async {
    final gateway = NativeDojahGateway((
      widgetId, {
      required referenceId,
    }) async {
      expect(widgetId, 'selfie-widget');
      expect(referenceId, 'boc-attempt-000001');
      return 'Verification Completed';
    });

    expect(
      await gateway.launch(
        widgetId: 'selfie-widget',
        referenceId: 'boc-attempt-000001',
      ),
      KycCaptureOutcome.unknown,
    );
  });

  test('maps the documented closed result to cancellation', () async {
    final gateway = NativeDojahGateway(
      (widgetId, {required referenceId}) async => 'closed',
    );

    expect(
      await gateway.launch(
        widgetId: 'government-widget',
        referenceId: 'boc-attempt-000002',
      ),
      KycCaptureOutcome.cancelled,
    );
  });

  test('rejects missing launch configuration before native code', () async {
    var launched = false;
    final gateway = NativeDojahGateway((
      widgetId, {
      required referenceId,
    }) async {
      launched = true;
      return 'closed';
    });

    await expectLater(
      gateway.launch(widgetId: '', referenceId: 'boc-attempt-000001'),
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
      (widgetId, {required referenceId}) => first,
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
