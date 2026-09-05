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
