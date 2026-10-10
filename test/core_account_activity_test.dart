import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_summary.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [data] in the Core envelope, recording it.
class _Core implements HttpClientAdapter {
  _Core([this.data]);
  final Object? data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data, 'meta': {}}),
      200,
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

void main() {
  group('summary', () {
    // Live staging (7 October 2026): the list's "99,864.50" came back here
    // as ledgerBalance 9986450, so these numbers are Kobo.
    test('reads Kobo balances as Naira and drops customerId', () {
      final summary = CoreAccountSummary.fromJson({
        'accountNumber': '1100919408',
        'customerId': 'C1',
        'name': 'ADA OBI',
        'product': 'Boc Flex',
        'branch': 'HQ',
        'accountStatus': 'active',
        'availableBalance': 765430,
        'ledgerBalance': 9986450,
      });
      expect(summary.availableBalance, '7654.30');
      expect(summary.ledgerBalance, '99864.50');
      expect(summary.status, CoreAccountStatus.active);
      expect(summary.props, isNot(contains('C1')));
    });

    test('is never requested for a malformed number', () async {
      final core = _Core({'accountNumber': '1100919408'});
      final service = _service(core);

      expect((await service.getAccountSummary('12')).isError, isTrue);
      expect(core.requests, isEmpty);

      await service.getAccountSummary('1100919408');
      expect(
        '${core.requests.single.method} ${core.requests.single.path}',
        'GET /me/bank-accounts/1100919408/summary',
      );
    });
  });

  test('transactions request the documented window and item count', () async {
    final core = _Core({'accountNumber': '1100919408', 'transactions': []});
    final service = _service(core);

    await service.getAccountTransactions(
      '1100919408',
      CoreHistoryRange.last30Days,
      today: DateTime(2026, 10, 7),
    );

    final request = core.requests.single;
    expect(request.path, '/me/bank-accounts/1100919408/transactions');
    expect(request.queryParameters, {
      'fromDate': '07-09-2026',
      'toDate': '07-10-2026',
      'numberOfItems': 50,
    });
  });

  // The logger then hides the account number in the path and every row.
  test('transactions are logged by path template only', () async {
    final core = _Core({'accountNumber': '1100919408', 'transactions': []});

    await _service(
      core,
    ).getAccountTransactions('1100919408', CoreHistoryRange.last7Days);

    expect(
      core.requests.single.extra[LoggingInterceptor.privacySensitivePathKey],
      '/me/bank-accounts/{accountNumber}/transactions',
    );
  });
}
