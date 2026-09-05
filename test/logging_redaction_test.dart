import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _CapturingOutput extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

void main() {
  late _CapturingOutput output;
  late LoggingInterceptor interceptor;

  setUp(() {
    output = _CapturingOutput();
    interceptor = LoggingInterceptor(
      includeSensitiveData: true,
      logger: Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: false, colors: false),
        output: output,
      ),
    );
  });

  test('staging still shows OTPs so testers can complete flows', () {
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: RequestOptions(path: '/auth/otp'),
        data: {'otp': '123456'},
      ),
      ResponseInterceptorHandler(),
    );
    expect(output.lines.join(), contains('123456'));
  });

  test('a serialized payload string does not leak its contents', () {
    // Found by a live staging check: the recursive redaction walked Map and
    // Iterable only, so a JSON-encoded string field printed every value inside
    // it verbatim. httpbin-style echo endpoints and any stringified upstream
    // body hit this.
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: RequestOptions(path: '/echo'),
        data: {
          'data':
              '{"accountNumber":"0123456789","auth_token":"smile-auth-token"}',
        },
      ),
      ResponseInterceptorHandler(),
    );
    final logged = output.lines.join();
    expect(logged, isNot(contains('0123456789')));
    expect(logged, isNot(contains('smile-auth-token')));
  });

  test('an ordinary string value is still logged in full', () {
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: RequestOptions(path: '/profile'),
        data: {'message': 'Your profile was updated.', 'otp': '123456'},
      ),
      ResponseInterceptorHandler(),
    );
    final logged = output.lines.join();
    expect(logged, contains('Your profile was updated.'));
    expect(logged, contains('123456'));
  });

  test(
    'never-log values are redacted even when sensitive data is included',
    () {
      interceptor.onResponse(
        Response<Object?>(
          requestOptions: RequestOptions(
            path: '/users/me/kyc/government-id/initiate',
          ),
          data: {
            'accountNumber': '0123456789',
            'auth_token': 'smile-auth-token',
            'partner_id': 'partner-test',
            'identityNumber': '12345678901',
            'documentNumber': 'AB1234567',
            'callbackUrl': 'https://user.example.test/hook?signature=secret',
          },
        ),
        ResponseInterceptorHandler(),
      );
      final logged = output.lines.join();
      for (final secret in [
        '0123456789',
        'smile-auth-token',
        'partner-test',
        '12345678901',
        'AB1234567',
        'signature=secret',
      ]) {
        expect(logged, isNot(contains(secret)));
      }
    },
  );
}
