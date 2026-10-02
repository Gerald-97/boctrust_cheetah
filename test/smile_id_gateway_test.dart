import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/smile_id_gateway.dart';
import 'package:boctrust_savings_loan/module/kyc/service/smile_id_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmileIdAssetConfig', () {
    test('parses portal config into FlutterConfig fields', () {
      final config = SmileIdAssetConfig.fromJson({
        'partner_id': 'partner-test',
        'auth_token': 'token-test',
        'prod_lambda_url': 'https://prod.example.test/v1/',
        'test_lambda_url': 'https://sandbox.example.test/v1/',
      });
      expect(config.partnerId, 'partner-test');
      expect(config.productionBaseUrl.host, 'prod.example.test');
      expect(config.sandboxBaseUrl.host, 'sandbox.example.test');
    });

    test('rejects missing credentials and non-HTTPS URLs', () {
      expect(
        () => SmileIdAssetConfig.fromJson({
          'partner_id': '',
          'auth_token': '',
          'prod_lambda_url': 'http://prod.example.test/v1/',
          'test_lambda_url': 'https://sandbox.example.test/v1/',
        }),
        throwsFormatException,
      );
    });
  });

  _biometricJobTests();

  group('SmileIdDocumentJob', () {
    KycInitiationData documentInitiation(String documentType) =>
        KycInitiationData.fromJson({
          'verificationId': 'verification-1',
          'product': 'enhanced_document_verification',
          'sdkJobType': 'enhancedDocumentVerification',
          'environment': 'sandbox',
          'country': 'NG',
          'documentType': documentType,
          'smileUserId': 'smile-user-1',
          'smileJobId': 'smile-job-1',
          'callbackUrl': 'https://user.example.test/document-webhook',
          'partnerParams': {
            'user_id': 'smile-user-1',
            'job_id': 'smile-job-1',
            'job_type': 11,
          },
        });

    test('maps backend government ID context to Smile v11 values', () {
      final job = SmileIdDocumentJob.fromInitiation(
        documentInitiation('voter_id'),
        useSandbox: true,
      );
      expect(job.documentType, 'VOTER_ID');
      expect(job.captureBothSides, isTrue);
      expect(job.userId, 'smile-user-1');
      expect(job.jobId, 'smile-job-1');
    });

    test('rejects documents Smile is not enabled for', () {
      // A Smile job is only ever built for a document Smile can verify; the
      // capability gate and the SDK mapping must both agree.
      for (final documentType in [
        'national_id',
        'international_passport',
        'nin_slip',
        'drivers_license',
      ]) {
        expect(
          () => SmileIdDocumentJob.fromInitiation(
            documentInitiation(documentType),
            useSandbox: true,
          ),
          throwsA(isA<SmileIdConfigurationException>()),
          reason: documentType,
        );
      }
    });

    test('rejects wrong products, HTTP callbacks, and conflicting IDs', () {
      expect(
        () => SmileIdDocumentJob.fromInitiation(
          KycInitiationData.fromJson({
            'verificationId': 'verification-2',
            'product': 'enhanced_document_verification',
            'sdkJobType': 'enhancedDocumentVerification',
            'environment': 'sandbox',
            'country': 'NG',
            'documentType': 'voter_id',
            'smileUserId': 'smile-user-1',
            'smileJobId': 'smile-job-1',
            'callbackUrl': 'http://user.example.test/document-webhook',
            'partnerParams': {
              'user_id': 'different-user',
              'job_id': 'smile-job-1',
              'job_type': '11',
            },
          }),
          useSandbox: true,
        ),
        throwsA(isA<SmileIdConfigurationException>()),
      );
    });
  });
}

/// Tier 1 Biometric KYC mapping (Smile job type 1).
void _biometricJobTests() {
  KycInitiationData initiation({
    String product = 'biometric_kyc',
    String sdkJobType = 'biometricKyc',
    Object jobType = 1,
    String? country = 'NG',
  }) => KycInitiationData.fromJson({
    'verificationId': 'verification-1',
    'product': product,
    'sdkJobType': sdkJobType,
    'environment': 'sandbox',
    'country': ?country,
    'identityType': 'bvn',
    'smileUserId': 'smile-user-1',
    'smileJobId': 'smile-job-1',
    'callbackUrl': 'https://user.example.test/webhook',
    'partnerParams': {'job_type': jobType},
  });

  final consent = KycCaptureConsent(
    grantedAtUtc: DateTime.utc(2026, 9, 6, 10, 30),
  );

  group('SmileIdBiometricJob', () {
    test('maps a BVN initiation to Smile SDK values', () {
      final job = SmileIdBiometricJob.fromInitiation(
        initiation(),
        useSandbox: true,
        identityType: IdentityType.bvn,
        identityNumber: '12345678901',
        consent: consent,
      );

      expect(job.idType, 'BVN');
      expect(job.idNumber, '12345678901');
      expect(job.country, 'NG');
      expect(job.userId, 'smile-user-1');
      expect(job.jobId, 'smile-job-1');
      expect(job.consent.grantedDate, '2026-09-06T10:30:00.000Z');
    });

    test('NIN maps to its own SDK value', () {
      final job = SmileIdBiometricJob.fromInitiation(
        initiation(),
        useSandbox: true,
        identityType: IdentityType.nin,
        identityNumber: '12345678901',
        consent: consent,
      );
      expect(job.idType, 'NIN');
    });

    test('country defaults to NG when the backend omits it', () {
      final job = SmileIdBiometricJob.fromInitiation(
        initiation(country: null),
        useSandbox: true,
        identityType: IdentityType.bvn,
        identityNumber: '12345678901',
        consent: consent,
      );
      expect(job.country, 'NG');
    });

    test(
      'an Enhanced KYC job is refused, because job 5 captures no selfie',
      () {
        expect(
          () => SmileIdBiometricJob.fromInitiation(
            initiation(product: 'enhanced_kyc', sdkJobType: 'enhancedKyc'),
            useSandbox: true,
            identityType: IdentityType.bvn,
            identityNumber: '12345678901',
            consent: consent,
          ),
          throwsA(isA<SmileIdConfigurationException>()),
        );
      },
    );

    test('a job type other than 1 is refused', () {
      expect(
        () => SmileIdBiometricJob.fromInitiation(
          initiation(jobType: 5),
          useSandbox: true,
          identityType: IdentityType.bvn,
          identityNumber: '12345678901',
          consent: consent,
        ),
        throwsA(isA<SmileIdConfigurationException>()),
      );
    });

    test('job type 1 is accepted as an int or a string', () {
      for (final jobType in <Object>[1, '1']) {
        expect(
          SmileIdBiometricJob.fromInitiation(
            initiation(jobType: jobType),
            useSandbox: true,
            identityType: IdentityType.bvn,
            identityNumber: '12345678901',
            consent: consent,
          ).jobId,
          'smile-job-1',
        );
      }
    });

    test('an empty identity number is refused before reaching the SDK', () {
      expect(
        () => SmileIdBiometricJob.fromInitiation(
          initiation(),
          useSandbox: true,
          identityType: IdentityType.bvn,
          identityNumber: '   ',
          consent: consent,
        ),
        throwsA(isA<SmileIdConfigurationException>()),
      );
    });
  });
}
