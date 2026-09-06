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

  test('server-masked Last4 fragments stay visible, full numbers do not', () {
    // Both are the masked display form the app renders on screen, so they must
    // behave identically. Before this, documentNumberLast4 was redacted only
    // because "documentnumber" is a substring of it, while identityLast4 was
    // visible because "identitynumber" is not.
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: RequestOptions(path: '/users/me/kyc/status'),
        data: {
          'identityLast4': '2222',
          'documentNumberLast4': '4567',
          'documentNumber': 'AB1234567',
          'identityNumber': '12345678901',
        },
      ),
      ResponseInterceptorHandler(),
    );
    final logged = output.lines.join();
    expect(logged, contains('2222'));
    expect(logged, contains('4567'));
    // The full identifiers are still caught.
    expect(logged, isNot(contains('AB1234567')));
  });

  test('identityNumber is visible in staging but redacted in production', () {
    // Deliberate, temporary: the BVN is needed in staging logs while the
    // Biometric KYC flow is built. It is environment-gated, never exposed in
    // production, and belongs back in the always-redact set afterwards.
    interceptor.onRequest(
      RequestOptions(
        path: '/users/me/kyc/identity/initiate',
        data: {'identityType': 'bvn', 'identityNumber': '12345678901'},
      ),
      RequestInterceptorHandler(),
    );
    expect(output.lines.join(), contains('12345678901'));

    final production = _CapturingOutput();
    LoggingInterceptor(
      includeSensitiveData: false,
      logger: Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: false, colors: false),
        output: production,
      ),
    ).onRequest(
      RequestOptions(
        path: '/users/me/kyc/identity/initiate',
        data: {'identityType': 'bvn', 'identityNumber': '12345678901'},
      ),
      RequestInterceptorHandler(),
    );
    expect(production.lines.join(), isNot(contains('12345678901')));
  });

  test('credentials are redacted even in staging, unlike OTPs', () {
    // Found by reading a real Android emulator logcat: a failed login had
    // written the plaintext password. A tester never needs to read back a
    // credential they just typed, and unlike an OTP a password is long-lived
    // and commonly reused, so it is redacted in every environment.
    // The leak was seen on the error path, which logs requestBody through the
    // same _visible call this exercises.
    interceptor.onRequest(
      RequestOptions(
        path: '/auth/login',
        data: {
          'identifier': 'user@example.test',
          'password': 'Sup3rSecret!',
          // Deliberately not a substring of the OTP below, so the assertions
          // cannot pass or fail for the wrong reason.
          'pin': '8888',
          'newPin': '7777',
          'otp': '123456',
        },
      ),
      RequestInterceptorHandler(),
    );
    final logged = output.lines.join();
    expect(logged, isNot(contains('Sup3rSecret!')));
    expect(logged, isNot(contains('8888')));
    expect(logged, isNot(contains('7777')));
    // The staging affordance is untouched.
    expect(logged, contains('123456'));
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
        'AB1234567',
        'signature=secret',
      ]) {
        expect(logged, isNot(contains(secret)));
      }
      // identityNumber is deliberately absent from this list: it is
      // environment-gated rather than always-redacted while the Biometric KYC
      // flow is built, so staging shows it. The staging/production split has
      // its own test above.
      expect(logged, contains('12345678901'));
    },
  );
}
