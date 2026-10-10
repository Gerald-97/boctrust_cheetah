import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_update_models.dart';
import 'package:boctrust_savings_loan/module/account/service/core_transaction_limit_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each path with [status] and its canned `data`, recording it.
class _Core implements HttpClientAdapter {
  _Core(this.replies, {this.status = 200});
  final Map<String, Object?> replies;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': status < 400,
        'message': 'ok',
        'data': replies[options.path],
        'meta': {},
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CoreTransactionLimitService _service(_Core core) => CoreTransactionLimitService(
  ApiService(
    Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
      ..httpClientAdapter = core,
  ),
);

void main() {
  // Swagger: initiate takes only the limits being changed; PIN and OTP go to
  // their verify routes; resend and finalize have no body.
  test('a limit change sends each step its own body', () async {
    final core = _Core({
      '/me/transaction-limits/initiate': {
        'reference': 'a1b2c3d4e5f6',
        'requiredChecks': ['pin', 'otp'],
        'expiresAt': '2099-01-01T00:00:00Z',
      },
    });
    final service = _service(core);

    final started = await service.initiateLimitUpdate(
      const TransactionLimitDraft(dailyTransferLimit: '5000000'),
    );
    await service.verifyLimitPin('a1b2c3d4e5f6', '0007');
    await service.resendLimitOtp('a1b2c3d4e5f6');
    await service.verifyLimitOtp('a1b2c3d4e5f6', '123456');
    await service.finalizeLimitUpdate('a1b2c3d4e5f6');

    expect(started.data?.reference, 'a1b2c3d4e5f6');
    expect(core.requests.map((r) => r.path), [
      '/me/transaction-limits/initiate',
      '/me/transaction-limits/a1b2c3d4e5f6/pin/verify',
      '/me/transaction-limits/a1b2c3d4e5f6/otp/resend',
      '/me/transaction-limits/a1b2c3d4e5f6/otp/verify',
      '/me/transaction-limits/a1b2c3d4e5f6/finalize',
    ]);
    expect(core.requests.map((r) => r.data), [
      {'dailyTransferLimit': '5000000'},
      {'transactionPin': '0007'},
      null,
      {'otpCode': '123456'},
      null,
    ]);
    // Full staging logs by product decision.
    expect(
      core.requests.map(
        (r) => r.extra[LoggingInterceptor.privacySensitivePathKey],
      ),
      everyElement(isNull),
    );
  });

  test('an unchanged draft is never sent', () async {
    final core = _Core({});

    final result = await _service(
      core,
    ).initiateLimitUpdate(const TransactionLimitDraft());

    expect(result.isError, isTrue);
    expect(core.requests, isEmpty);
  });

  test('a failed step is never retried', () async {
    for (final status in [400, 401, 403, 404, 409, 500]) {
      final core = _Core({}, status: status);

      await _service(core).finalizeLimitUpdate('a1b2c3d4e5f6');

      expect(core.requests, hasLength(1), reason: '$status');
    }
  });
}
