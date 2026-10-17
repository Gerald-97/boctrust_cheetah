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

  test('prose and status flags survive, only payload strings are scanned', () {
    // Both regressions were found by reading a real Android emulator logcat.
    // A message merely mentioning a protected word vanished, and boolean
    // onboarding flags were redacted because their key names contain
    // "password" and "pin" — destroying the fields logs are read for.
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: RequestOptions(path: '/auth/password/forgot'),
        data: {
          'message': 'A password reset link has been sent to your email.',
          'isCreatedPassword': true,
          'isCreatedPin': false,
          'password': 'Sup3rSecret!',
        },
      ),
      ResponseInterceptorHandler(),
    );
    final logged = output.lines.join();
    expect(logged, contains('A password reset link has been sent'));
    expect(logged, contains('"isCreatedPassword":true'));
    expect(logged, contains('"isCreatedPin":false'));
    // The actual credential is still gone.
    expect(logged, isNot(contains('Sup3rSecret!')));
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
      // Account numbers are likewise environment-gated until launch.
      expect(logged, contains('0123456789'));
    },
  );

  test('Core customer IDs are visible in staging, redacted in production', () {
    RequestOptions bill() => RequestOptions(
      path: '/me/bills/payments',
      data: {'customerId': '04512345678', 'amount': '1000.00'},
    );
    interceptor.onRequest(bill(), RequestInterceptorHandler());
    expect(output.lines.join(), contains('04512345678'));

    final production = _CapturingOutput();
    LoggingInterceptor(
      includeSensitiveData: false,
      logger: Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: false, colors: false),
        output: production,
      ),
    ).onRequest(bill(), RequestInterceptorHandler());
    expect(production.lines.join(), isNot(contains('04512345678')));
    expect(production.lines.join(), contains('1000.00'));
  });

  test(
    'bank-account replies are verbatim in staging, redacted in production',
    () {
      RequestOptions request() => RequestOptions(
        baseUrl: 'https://core.test/api/v1',
        path: '/me/bank-accounts/1100919408/unfreeze/otp',
        method: 'POST',
        extra: const {
          'apiLogger.privacySensitivePath':
              '/me/bank-accounts/{accountNumber}/unfreeze/otp',
        },
      );
      Response<Object?> reply() => Response<Object?>(
        requestOptions: request(),
        statusCode: 200,
        data: {'accountNumber': '1100919408', 'otpCode': '482913'},
      );
      interceptor.onResponse(reply(), ResponseInterceptorHandler());
      expect(output.lines.join(), contains('1100919408'));
      expect(output.lines.join(), contains('482913'));

      final production = _CapturingOutput();
      LoggingInterceptor(
        includeSensitiveData: false,
        logger: Logger(
          filter: ProductionFilter(),
          printer: SimplePrinter(printTime: false, colors: false),
          output: production,
        ),
      ).onResponse(reply(), ResponseInterceptorHandler());
      expect(production.lines.join(), isNot(contains('482913')));
      expect(production.lines.join(), isNot(contains('1100919408')));
    },
  );

  test('privacy-sensitive enquiry hides its account path and body', () {
    final request = RequestOptions(
      baseUrl: 'https://core.test/api/v1',
      path: '/accounts/1100037777/enquiry',
      method: 'GET',
      extra: const {
        'apiLogger.privacySensitivePath': '/accounts/{accountNumber}/enquiry',
      },
    );
    interceptor.onResponse(
      Response<Object?>(
        requestOptions: request,
        statusCode: 200,
        data: {
          'name': 'ADA OBI',
          'bvn': '22222222222',
          'kycLevel': '3',
          'availableBalance': '42000.00',
        },
      ),
      ResponseInterceptorHandler(),
    );
    interceptor.onError(
      DioException(
        requestOptions: request,
        message: 'Account 1100037777 has balance 42000.00',
        response: Response<Object?>(
          requestOptions: request,
          statusCode: 409,
          data: {'name': 'ADA OBI', 'bvn': '22222222222'},
        ),
      ),
      _SwallowingErrorHandler(),
    );

    final logged = output.lines.join();
    expect(
      logged,
      contains('https://core.test/api/v1/accounts/{accountNumber}/enquiry'),
    );
    for (final sensitive in [
      '1100037777',
      'ADA OBI',
      '22222222222',
      '42000.00',
    ]) {
      expect(logged, isNot(contains(sensitive)));
    }
  });

  group('a credential-bearing request', () {
    // Prints everything Logger receives, including error and stack trace,
    // so nothing the interceptor hands over can hide from the assertion.
    late List<String> emitted;
    late LoggingInterceptor staging;

    setUp(() {
      emitted = [];
      staging = LoggingInterceptor(
        includeSensitiveData: true,
        logger: Logger(
          filter: ProductionFilter(),
          printer: _EverythingPrinter(emitted),
          output: _CapturingOutput(),
        ),
      );
    });

    RequestOptions transfer() => RequestOptions(
      path: '/me/intrabank/transfers',
      method: 'POST',
      data: {
        'toAccountNumber': '1100037777',
        'amount': '1000',
        'nested': {'transactionPin': '0007'},
      },
    );

    test('keeps the PIN out of a structured request body', () {
      staging.onRequest(transfer(), RequestInterceptorHandler());
      expect(emitted.join(), isNot(contains('0007')));
    });

    test('never logs a raw error message, error or stack trace in staging', () {
      final request = transfer();
      staging.onError(
        DioException(
          requestOptions: request,
          message: 'Bad PIN 0007 for transfer',
          error: StateError('pin 0007 rejected'),
          stackTrace: StackTrace.fromString('#0 submit (pin=0007)'),
          response: Response<Object?>(
            requestOptions: request,
            statusCode: 401,
            data: 'The transaction PIN 0007 is incorrect.',
          ),
        ),
        _SwallowingErrorHandler(),
      );
      final logged = emitted.join('\n');
      expect(logged, contains('401'));
      expect(logged, isNot(contains('0007')));
    });

    test('masks a PIN the server echoes in a response', () {
      final request = transfer();
      staging.onResponse(
        Response<Object?>(
          requestOptions: request,
          statusCode: 200,
          data: {'message': 'PIN 0007 accepted'},
        ),
        ResponseInterceptorHandler(),
      );
      expect(emitted.join(), isNot(contains('0007')));
    });

    test('an ordinary request still logs its raw error in staging', () {
      final request = RequestOptions(path: '/me/bank-accounts');
      staging.onError(
        DioException(
          requestOptions: request,
          message: 'Connection reset by peer',
        ),
        _SwallowingErrorHandler(),
      );
      expect(emitted.join(), contains('Connection reset by peer'));
    });
  });
}

class _EverythingPrinter extends LogPrinter {
  _EverythingPrinter(this.sink);
  final List<String> sink;

  @override
  List<String> log(LogEvent event) {
    final lines = [
      '${event.message}',
      if (event.error != null) 'error: ${event.error}',
      if (event.stackTrace != null) 'stack: ${event.stackTrace}',
    ];
    sink.addAll(lines);
    return lines;
  }
}

/// Records nothing and lets the error stop here, so a test can call
/// `onError` without an unhandled future.
class _SwallowingErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
}
