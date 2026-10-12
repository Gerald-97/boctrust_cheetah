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

  test('transactions request YYYY-MM-DD dates and a page', () async {
    final core = _Core({'accountNumber': '1100919408', 'transactions': []});
    final service = _service(core);

    await service.getAccountTransactions(
      '1100919408',
      CoreHistoryRange.last30Days,
      page: 2,
      today: DateTime(2026, 10, 7),
    );

    final request = core.requests.single;
    expect(request.path, '/me/bank-accounts/1100919408/transactions');
    expect(request.queryParameters, {
      'fromDate': '2026-09-07',
      'toDate': '2026-10-07',
      'page': 2,
      'pageSize': 20,
    });
  });

  test('rows parse with their documented fields', () async {
    final core = _Core({
      'accountNumber': '1100919408',
      'transactions': [
        {
          'id': '922223',
          'date': '2026-10-10T20:17:35',
          'type': 'debit',
          'amount': '40.38',
          'balance': '1009900.62',
          'narration': 'POS',
          'coreBankingReference': 'CB1',
          'reversed': false,
        },
      ],
      'pagination': {'page': 1, 'pageSize': 20, 'total': 45, 'totalPages': 3},
    });

    final result = await _service(
      core,
    ).getAccountTransactions('1100919408', CoreHistoryRange.last7Days);

    final page = result.data!;
    final row = page.rows.single;
    expect(row.amount, '40.38');
    expect(row.type, CoreTransactionType.debit);
    expect(row.date, DateTime(2026, 10, 10, 20, 17, 35));
    expect(page.page!.hasMore, isTrue);
  });

  test('direction comes from type, not the amount text', () async {
    final core = _Core({
      'accountNumber': '1100919408',
      'transactions': [
        {'id': '1', 'type': 'credit', 'amount': '-40.38'},
        {'id': '2', 'type': 'refund', 'amount': '40.38'},
      ],
    });

    final result = await _service(
      core,
    ).getAccountTransactions('1100919408', CoreHistoryRange.last7Days);

    expect(result.data!.rows, isEmpty);
  });

  test('transactions are logged in full on staging', () async {
    final core = _Core({'accountNumber': '1100919408', 'transactions': []});

    await _service(
      core,
    ).getAccountTransactions('1100919408', CoreHistoryRange.last7Days);

    expect(
      core.requests.single.extra,
      isNot(contains(LoggingInterceptor.privacySensitivePathKey)),
    );
  });
}
