import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bill_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_beneficiary_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_bill_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each path with its canned `data`, recording every request.
class _Core implements HttpClientAdapter {
  _Core(this.replies);

  final Map<String, Object?> replies;
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
        'message': 'ok',
        'data': replies[options.path],
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

ApiService _api(_Core core) => ApiService(
  Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
    ..httpClientAdapter = core,
);

void main() {
  test('transfers and interbank reads use the documented endpoints', () async {
    final core = _Core({
      '/me/interbank/banks': [
        {'code': '000014', 'name': 'Zenith'},
      ],
      '/me/interbank/name-enquiry': {'name': 'ADA OBI', 'bvn': '1'},
      '/me/intrabank/transfers': {'responseCode': '00', 'reference': 'r1'},
      '/me/interbank/transfers': {'status': 'pending', 'reference': 'r/2'},
      '/me/interbank/transfers/r%2F2/status': {'status': 'completed'},
    });
    final service = CoreTransferService(_api(core));

    expect((await service.getBanks()).data?.single.code, '000014');
    expect(
      (await service.nameEnquiry(
        bankCode: '000014',
        accountNumber: '0123456789',
      )).data,
      const NameEnquiryResult('ADA OBI'),
    );
    await service.transferToBoctrust(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '1',
      ),
    );
    final sent = await service.transferToOtherBank(
      const InterbankTransferDraft(
        bankCode: '000014',
        bankName: 'Zenith',
        accountNumber: '0123456789',
        accountName: 'ADA OBI',
        amountKobo: '5000',
      ),
    );
    final status = await service.getTransferStatus(sent.data!.reference!);

    expect(status.data?.state, InterbankTransferState.completed);
    expect(core.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /me/interbank/banks',
      'POST /me/interbank/name-enquiry',
      'POST /me/intrabank/transfers',
      'POST /me/interbank/transfers',
      'GET /me/interbank/transfers/r%2F2/status',
    ]);
    expect(core.requests[1].data, {
      'accountNumber': '0123456789',
      'bankCode': '000014',
    });
    expect(core.requests[2].data, {
      'toAccountNumber': '1100037777',
      'amount': '1',
    });
  });

  test('bill catalogues and payment', () async {
    final core = _Core({
      '/me/bills/billers/categories': [
        {'id': '4', 'name': 'Mobile/Recharge', 'isAirtime': true},
      ],
      '/me/bills/billers': [
        {'billerId': 157, 'billerCategoryId': '4', 'name': 'MTN'},
      ],
      '/me/bills/payment-items': [
        {'id': 'i1', 'billerId': '157', 'name': 'Top up', 'amount': 0},
      ],
      '/me/bills/payments': {'status': 'Successful', 'responseCode': '00'},
    });
    final service = CoreBillService(_api(core));

    expect((await service.getCategories()).data?.single.isAirtime, isTrue);
    expect((await service.getBillers()).data?.single.id, '157');
    expect((await service.getPaymentItems()).data?.single.amountNaira, isNull);
    final paid = await service.pay(
      const BillPaymentDraft(
        billerId: '157',
        paymentItemId: 'i1',
        customerId: '08030000000',
        amountNaira: '100.00',
      ),
    );

    expect(paid.data?.responseCode, '00');
    expect(core.requests.last.data, {
      'billerId': '157',
      'paymentItemId': 'i1',
      'customerId': '08030000000',
      'amount': '100.00',
    });
  });

  test('beneficiaries list, add and delete', () async {
    final row = {
      'beneficiaryId': 'b/1',
      'type': 'bank_account',
      'number': '0123456789',
      'name': 'ADA OBI',
    };
    final core = _Core({
      '/me/beneficiaries': [row],
      '/me/beneficiaries/b%2F1': null,
    });
    final service = CoreBeneficiaryService(_api(core));

    expect((await service.list()).data?.single.id, 'b/1');
    core.replies['/me/beneficiaries'] = row;
    final added = await service.add({'type': 'bank_account'});
    final deleted = await service.delete('b/1');

    expect(added.data?.id, 'b/1');
    expect(deleted.status, ServiceStatus.success);
    expect(core.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /me/beneficiaries',
      'POST /me/beneficiaries',
      'DELETE /me/beneficiaries/b%2F1',
    ]);
  });

  test('unconfigured Core sends nothing', () async {
    expect(
      (await const CoreTransferService(null).getBanks()).status,
      ServiceStatus.blocked,
    );
    expect(
      (await const CoreBillService(null).getBillers()).status,
      ServiceStatus.blocked,
    );
    expect(
      (await const CoreBeneficiaryService(null).list()).status,
      ServiceStatus.blocked,
    );
  });
}
