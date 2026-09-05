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

  group('SmileIdDocumentJob', () {
    test('maps backend government ID context to Smile v11 values', () {
      final job = SmileIdDocumentJob.fromInitiation(
        KycInitiationData.fromJson({
          'verificationId': 'verification-1',
          'product': 'enhanced_document_verification',
          'sdkJobType': 'enhancedDocumentVerification',
          'environment': 'sandbox',
          'country': 'NG',
          'documentType': 'international_passport',
          'smileUserId': 'smile-user-1',
          'smileJobId': 'smile-job-1',
          'callbackUrl': 'https://user.example.test/document-webhook',
          'partnerParams': {
            'user_id': 'smile-user-1',
            'job_id': 'smile-job-1',
            'job_type': 11,
          },
        }),
        useSandbox: true,
      );
      expect(job.documentType, 'PASSPORT');
      expect(job.captureBothSides, isFalse);
      expect(job.userId, 'smile-user-1');
      expect(job.jobId, 'smile-job-1');
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
