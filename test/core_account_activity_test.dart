import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_summary.dart';
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
    test('parses numeric balances to exact strings and drops customerId', () {
      final summary = CoreAccountSummary.fromJson({
        'accountNumber': '1100919408',
        'customerId': 'C1',
        'name': 'ADA OBI',
        'product': 'Boc Flex',
        'branch': 'HQ',
        'accountStatus': 'active',
        'availableBalance': 7654.3,
        'ledgerBalance': 100,
      });
      expect(summary.availableBalance, '7654.30');
      expect(summary.ledgerBalance, '100.00');
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
}
