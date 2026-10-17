import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/account_freeze_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [status] and [data], recording each one.
class _Core implements HttpClientAdapter {
  _Core(this.data, {this.status = 200});

  final Object? data;
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
        'data': data,
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

CoreAccountService _service(_Core core) => CoreAccountService(
  ApiService(
    Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
      ..httpClientAdapter = core,
  ),
);

const _frozen = {
  'accountNumber': '1100925452',
  'status': 'frozen',
  'frozenBy': 'customer',
  'frozenAt': '2026-10-17T09:00:00Z',
};

void main() {
  test('freeze and unfreeze post the encoded path and exact body', () async {
    final core = _Core(_frozen);
    final service = _service(core);

    final freeze = await service.freezeAccount('1100925452', '1234');
    await service.unfreezeAccount('1100925452', '1234', '654321');

    expect(
      freeze,
      FreezeSucceeded(
        AccountFreezeResult(
          accountNumber: '1100925452',
          status: CoreAccountStatus.frozen,
          frozenBy: CoreFrozenBy.customer,
          frozenAt: DateTime.utc(2026, 10, 17, 9),
        ),
      ),
    );
    final [freezeRequest, unfreezeRequest] = core.requests;
    expect(freezeRequest.method, 'POST');
    expect(freezeRequest.path, '/me/bank-accounts/1100925452/freeze');
    expect(freezeRequest.data, {'transactionPin': '1234'});
    expect(unfreezeRequest.path, '/me/bank-accounts/1100925452/unfreeze');
    expect(unfreezeRequest.data, {
      'transactionPin': '1234',
      'otpCode': '654321',
    });
    // The logger sees only the template, never the PIN or the code.
    expect(
      unfreezeRequest.extra[LoggingInterceptor.privacySensitivePathKey],
      '/me/bank-accounts/{accountNumber}/unfreeze',
    );
  });

  test('the unfreeze code reply drops the staging-only otpCode', () async {
    final core = _Core({
      'otpSent': true,
      'otpExpiresAt': '2026-10-17T09:05:00Z',
      'otpCode': '654321',
    });

    final outcome = await _service(core).sendUnfreezeOtp('1100925452');

    expect(
      outcome,
      FreezeSucceeded(
        UnfreezeOtpReply(
          otpSent: true,
          otpExpiresAt: DateTime.utc(2026, 10, 17, 9, 5),
        ),
      ),
    );
    expect(
      core.requests.single.path,
      '/me/bank-accounts/1100925452/unfreeze/otp',
    );
    expect(core.requests.single.data, isNull);
  });

  test('a 403 means the bank froze the account', () async {
    final outcome = await _service(
      _Core(null, status: 403),
    ).sendUnfreezeOtp('1100925452');

    expect(outcome, isA<FreezeBankFrozen<UnfreezeOtpReply>>());
  });
}
