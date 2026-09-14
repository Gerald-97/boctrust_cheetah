import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _dojahIdentity() => {
  'contractVersion': 2,
  'verificationId': 'verification-1',
  'attemptId': 'attempt-1',
  'provider': 'dojah',
  'operation': 'identity',
  'environment': 'sandbox',
  'identityType': 'bvn',
  'identityLast4': '8901',
  'country': 'NG',
  'referenceId': 'boc-attempt-000001',
  'launchExpiresAt': '2030-01-01T12:00:00Z',
  'policyVersion': 'kyc-v2-1',
  'allowedAlternatives': ['smile_id'],
};

void main() {
  group('KycInitiationData provider context', () {
    test('parses a Dojah attempt without Smile credentials', () {
      final data = KycInitiationData.fromJson(_dojahIdentity());

      expect(data.contractVersion, 2);
      expect(data.attemptId, 'attempt-1');
      expect(data.referenceId, 'boc-attempt-000001');
      expect(data.launchExpiresAt, DateTime.utc(2030, 1, 1, 12));
      expect(data.allowedAlternatives, const ['smile_id']);
    });

    test('unknown explicit provider is rejected', () {
      final data = KycInitiationData.fromJson({
        ..._dojahIdentity(),
        'provider': 'unknown_provider',
      });

      expect(
        () => validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2029),
        ),
        throwsFormatException,
      );
    });

    test('expired Dojah context is rejected', () {
      final data = KycInitiationData.fromJson(_dojahIdentity());

      expect(
        () => validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2031),
        ),
        throwsFormatException,
      );
    });

    test('legacy Smile context remains supported', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'verification-1',
        'environment': 'sandbox',
        'smileUserId': 'user-1',
        'smileJobId': 'job-1',
        'callbackUrl': 'https://example.test/callback',
      });

      expect(
        validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2029),
        ),
        KycProvider.smileId,
      );
    });

    test('explicit Smile provider remains compatible with the v1 response', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'verification-1',
        'provider': 'smile_id',
        'environment': 'sandbox',
        'smileUserId': 'user-1',
        'smileJobId': 'job-1',
        'callbackUrl': 'https://example.test/callback',
      });

      expect(
        validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2029),
        ),
        KycProvider.smileId,
      );
    });
  });

  group('DojahConfig', () {
    test('selects a different widget for each operation', () {
      const config = DojahConfig(
        selfieWidgetId: 'selfie-widget',
        governmentWidgetId: 'government-widget',
      );

      expect(config.widgetIdFor(KycOperation.identity), 'selfie-widget');
      expect(
        config.widgetIdFor(KycOperation.governmentId),
        'government-widget',
      );
    });

    test('missing selfie widget does not disable government ID', () {
      const config = DojahConfig(
        selfieWidgetId: '',
        governmentWidgetId: 'government-widget',
      );

      expect(config.isConfigured(KycOperation.identity), isFalse);
      expect(config.isConfigured(KycOperation.governmentId), isTrue);
    });
  });

  test('capture outcomes map to non-authoritative flow stages', () {
    expect(
      stageAfterCapture(KycCaptureOutcome.submitted),
      KycFlowStage.pendingReview,
    );
    expect(
      stageAfterCapture(KycCaptureOutcome.cancelled),
      KycFlowStage.awaitingProvider,
    );
    expect(stageAfterCapture(KycCaptureOutcome.failed), KycFlowStage.failed);
    expect(
      stageAfterCapture(KycCaptureOutcome.unknown),
      KycFlowStage.reconciling,
    );
  });
}
