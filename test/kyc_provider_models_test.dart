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

/// The identity initiation the dev backend returns for Dojah today: no
/// contract version, attempt ID, operation, expiry, or `referenceId`.
Map<String, Object?> _dojahWithoutAttemptContract() => {
  'verificationId': 'kiv-586469d0b1aa11f192e81331ec2402a2',
  'provider': 'dojah',
  'product': 'bvn_selfie',
  'environment': 'sandbox',
  'sdkJobType': 'dojahBvnSelfie',
  'jobType': 'dojahBvnSelfie',
  'identityType': 'bvn',
  'identityLast4': '0006',
  'smileUserId': 'user-2939e55eb1aa11f1994bdf80cc340f81',
  'smileJobId': 'dojah-3e4eb50d-adde-4b40-ab44-480911551ffe',
  'providerUserId': 'user-2939e55eb1aa11f1994bdf80cc340f81',
  'providerJobId': 'dojah-3e4eb50d-adde-4b40-ab44-480911551ffe',
  'providerReference': 'dojah-3e4eb50d-adde-4b40-ab44-480911551ffe',
  'callbackUrl': 'https://example.test/callback',
  'partnerParams': {
    'user_id': 'user-2939e55eb1aa11f1994bdf80cc340f81',
    'job_id': 'dojah-3e4eb50d-adde-4b40-ab44-480911551ffe',
    'job_type': 'bvn_selfie',
  },
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

    test('Dojah reference falls back to providerJobId', () {
      final data = KycInitiationData.fromJson({
        ..._dojahWithoutAttemptContract(),
        'providerReference': 'provider-reference',
      });

      expect(data.referenceId, 'dojah-3e4eb50d-adde-4b40-ab44-480911551ffe');
    });

    test('explicit referenceId wins over providerJobId', () {
      final data = KycInitiationData.fromJson({
        ..._dojahIdentity(),
        'providerJobId': 'provider-job',
      });

      expect(data.referenceId, 'boc-attempt-000001');
    });

    test('Dojah launches without the attempt contract fields', () {
      final data = KycInitiationData.fromJson(_dojahWithoutAttemptContract());

      expect(
        validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2026, 9, 16),
        ),
        KycProvider.dojah,
      );
    });

    test('Dojah without the attempt contract still needs a reference', () {
      final data = KycInitiationData.fromJson(
        {..._dojahWithoutAttemptContract()}..remove('providerJobId'),
      );

      expect(
        () => validateKycLaunch(
          data,
          operation: KycOperation.identity,
          useSandbox: true,
          now: DateTime.utc(2026, 9, 16),
        ),
        throwsFormatException,
      );
    });

    test(
      'Dojah without the attempt contract rejects a different operation',
      () {
        final data = KycInitiationData.fromJson({
          ..._dojahWithoutAttemptContract(),
          'operation': 'government_id',
        });

        expect(
          () => validateKycLaunch(
            data,
            operation: KycOperation.identity,
            useSandbox: true,
            now: DateTime.utc(2026, 9, 16),
          ),
          throwsFormatException,
        );
      },
    );

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

    test('sandbox sends Dojah its test BVN instead of the entered one', () {
      expect(
        dojahCaptureBvn('00000000006', environment: 'sandbox'),
        '22222222222',
      );
    });

    test('live sends Dojah the entered BVN', () {
      expect(
        dojahCaptureBvn('00000000006', environment: 'live'),
        '00000000006',
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

  group('unsupported document message', () {
    const offered = GovernmentIdDocumentType.values;

    test('Dojah needs no message for any document type', () {
      for (final type in GovernmentIdDocumentType.values) {
        expect(
          governmentIdUnsupportedMessage(
            type,
            KycProvider.dojah,
            offeredTypes: offered,
          ),
          isNull,
          reason: '${type.wireValue} is launchable on Dojah',
        );
      }
    });

    test('Smile names a document the user can switch to', () {
      // The page offers a document chooser again, so the message points at
      // a document that works rather than at support.
      final message = governmentIdUnsupportedMessage(
        GovernmentIdDocumentType.ninSlip,
        KycProvider.smileId,
        offeredTypes: offered,
      );

      expect(message, contains(GovernmentIdDocumentType.ninSlip.label));
      expect(message, contains(GovernmentIdDocumentType.voterId.label));
      expect(message, isNot(contains('contact support')));
    });

    test('Smile never suggests a document the catalogue does not offer', () {
      final message = governmentIdUnsupportedMessage(
        GovernmentIdDocumentType.ninSlip,
        KycProvider.smileId,
        offeredTypes: const [
          GovernmentIdDocumentType.ninSlip,
          GovernmentIdDocumentType.nationalId,
        ],
      );

      expect(message, isNot(contains(GovernmentIdDocumentType.voterId.label)));
      expect(message, contains('contact support'));
    });

    test('Smile needs no message for voter ID', () {
      expect(
        governmentIdUnsupportedMessage(
          GovernmentIdDocumentType.voterId,
          KycProvider.smileId,
          offeredTypes: offered,
        ),
        isNull,
      );
    });

    test('Smile cannot launch national_id', () {
      expect(
        GovernmentIdDocumentType.nationalId.isEnabledFor(KycProvider.smileId),
        isFalse,
      );
      expect(
        GovernmentIdDocumentType.nationalId.isEnabledFor(KycProvider.dojah),
        isTrue,
      );
    });
  });

  group('Smile document spec', () {
    test('known Smile documents keep their SDK values', () {
      expect(
        GovernmentIdDocumentType.voterId.smileIdDocumentSpec,
        const SmileIdDocumentSpec(
          wireValue: 'VOTER_ID',
          captureBothSides: true,
        ),
      );
      expect(
        GovernmentIdDocumentType.driversLicense.smileIdDocumentSpec,
        const SmileIdDocumentSpec(
          wireValue: 'DRIVERS_LICENSE',
          captureBothSides: true,
        ),
      );
      expect(
        GovernmentIdDocumentType.internationalPassport.smileIdDocumentSpec,
        const SmileIdDocumentSpec(
          wireValue: 'PASSPORT',
          captureBothSides: false,
        ),
      );
      expect(
        GovernmentIdDocumentType.ninSlip.smileIdDocumentSpec,
        const SmileIdDocumentSpec(
          wireValue: 'NIN_SLIP',
          captureBothSides: false,
        ),
      );
    });

    test('national_id has no invented Smile mapping', () {
      expect(GovernmentIdDocumentType.nationalId.smileIdDocumentSpec, isNull);
    });
  });

  group('document type parsing', () {
    test('reads the wire values the backend sends back', () {
      expect(
        GovernmentIdDocumentType.tryParse('nin_slip'),
        GovernmentIdDocumentType.ninSlip,
      );
      expect(GovernmentIdDocumentType.tryParse('passport'), isNull);
      expect(GovernmentIdDocumentType.tryParse(null), isNull);
    });

    test('an unnamed document is not reported as unsupported', () {
      // The backend need not name a document before capture: the provider
      // decides. Only a named, unlaunchable one is worth blocking.
      expect(
        governmentIdUnsupportedMessage(
          null,
          KycProvider.smileId,
          offeredTypes: GovernmentIdDocumentType.values,
        ),
        isNull,
      );
    });
  });
}
