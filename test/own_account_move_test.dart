import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements HttpClientAdapter {
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
        'success': true,
        'message': 'Transfer request accepted.',
        'data': {'responseCode': '00', 'reference': 'ref-1'},
        'meta': {},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('moves send exact Kobo bodies to the right endpoint', () async {
    final recorder = _Recorder();
    final service = CoreTransferService(
      ApiService(
        Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
          ..httpClientAdapter = recorder,
      ),
    );

    final toSavings = await service.moveBetweenOwnAccounts(
      const OwnAccountMoveDraft(
        direction: OwnAccountDirection.toSavings,
        productCode: 'bocSmartSave',
        amountKobo: '150000',
        narration: '  Rent  ',
      ),
    );
    await service.moveBetweenOwnAccounts(
      const OwnAccountMoveDraft(
        direction: OwnAccountDirection.toFlex,
        productCode: 'bocSmartSave',
        amountKobo: '100',
      ),
    );

    expect(
      toSavings.data,
      const CoreTransferAck(responseCode: '00', reference: 'ref-1'),
    );
    expect(recorder.requests[0].path, '/me/intrabank/transfers/own');
    expect(recorder.requests[0].data, {
      'toProductCode': 'bocSmartSave',
      'amount': '150000',
      'narration': 'Rent',
    });
    expect(recorder.requests[1].path, '/me/intrabank/withdrawals');
    expect(recorder.requests[1].data, {
      'fromProductCode': 'bocSmartSave',
      'amount': '100',
    });
  });
}
