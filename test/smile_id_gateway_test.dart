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
}
