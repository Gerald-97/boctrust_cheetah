import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/own_account_move_screen.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

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

  testWidgets('a tab on Between my accounts switches to that section', (
    tester,
  ) async {
    final selected = <AppSection>[];
    var exits = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: await flowTestOverrides(),
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: OwnAccountMoveFlow(
            onExit: () => exits++,
            onSectionSelected: selected.add,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Account').last);
    await tester.pump();

    expect(selected, [AppSection.account]);
    expect(exits, 0);
  });
}
