import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bill_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
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
  test('transfers and recipient reads use the documented endpoints', () async {
    final core = _Core({
      '/accounts/1100037777/enquiry': {
        'name': 'ADA OBI',
        'number': '1100037777',
        'bvn': '22222222222',
      },
      '/me/interbank/banks': [
        {'code': '000014', 'name': 'Zenith'},
      ],
      '/me/interbank/name-enquiry': {'name': 'ADA OBI', 'bvn': '1'},
      '/me/intrabank/transfers': {'responseCode': '00', 'reference': 'r1'},
      '/me/interbank/transfers': {'status': 'pending', 'reference': 'r/2'},
      '/me/interbank/transfers/r%2F2/status': {'status': 'completed'},
    });
    final service = CoreTransferService(_api(core));

    expect(
      (await service.boctrustNameEnquiry('1100037777')).data,
      const NameEnquiryResult('ADA OBI'),
    );
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
      transactionPin: '0007',
    );
    final sent = await service.transferToOtherBank(
      const InterbankTransferDraft(
        bankCode: '000014',
        bankName: 'Zenith',
        accountNumber: '0123456789',
        accountName: 'ADA OBI',
        amountKobo: '5000',
      ),
      transactionPin: '0007',
    );
    final status = await service.getTransferStatus(sent.data!.reference!);

    expect(status.data?.state, InterbankTransferState.completed);
    expect(core.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /accounts/1100037777/enquiry',
      'GET /me/interbank/banks',
      'POST /me/interbank/name-enquiry',
      'POST /me/intrabank/transfers',
      'POST /me/interbank/transfers',
      'GET /me/interbank/transfers/r%2F2/status',
    ]);
    expect(core.requests[2].data, {
      'accountNumber': '0123456789',
      'bankCode': '000014',
    });
    expect(core.requests[3].data, {
      'toAccountNumber': '1100037777',
      'amount': '1',
      'transactionPin': '0007',
    });
    expect(core.requests[4].data, containsPair('transactionPin', '0007'));
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

    expect((await service.getCategories()).data?.single.id, '4');
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
      (await const CoreTransferService(
        null,
      ).boctrustNameEnquiry('1100037777')).status,
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

  test('a malformed BOCTRUST enquiry number never reaches the path', () async {
    final core = _Core({});

    final result = await CoreTransferService(
      _api(core),
    ).boctrustNameEnquiry('11/../me');

    expect(result.status, ServiceStatus.error);
    expect(core.requests, isEmpty);
  });

  group('live re-query', () {
    test('interbank uses transactionReference and sends no body', () async {
      final core = _Core({
        '/me/interbank/transfers/TX%2F9/requery': {
          'transactionReference': 'TX/9',
          'status': 'Successful',
          'responseCode': '00',
          'isReversed': false,
        },
      });
      final result = await CoreTransferService(_api(core)).requeryTransfer(
        const CoreTrackingReference(CoreTransferKind.interbank, 'TX/9'),
      );

      expect(result.data?.state, CoreLiveState.completed);
      expect(core.requests.single.method, 'POST');
      expect(
        core.requests.single.path,
        '/me/interbank/transfers/TX%2F9/requery',
      );
      expect(core.requests.single.data, isNull);
    });

    test('intrabank uses retrievalReference', () async {
      final core = _Core({
        '/me/intrabank/transfers/a1b2c3d4e5f6/requery': {
          'retrievalReference': 'a1b2c3d4e5f6',
          'status': 'Failed',
          'responseCode': '51',
        },
      });
      final result = await CoreTransferService(_api(core)).requeryTransfer(
        const CoreTrackingReference(CoreTransferKind.intrabank, 'a1b2c3d4e5f6'),
      );

      expect(result.data?.state, CoreLiveState.failed);
      expect(core.requests.single.data, isNull);
    });

    test('a malformed reference is rejected before the network', () async {
      final core = _Core({});
      final service = CoreTransferService(_api(core));

      final bad = await service.requeryTransfer(
        const CoreTrackingReference(CoreTransferKind.intrabank, 'NOT-HEX'),
      );
      final blank = await service.requeryTransfer(
        const CoreTrackingReference(CoreTransferKind.interbank, ''),
      );

      expect(bad.isError, isTrue);
      expect(blank.isError, isTrue);
      expect(core.requests, isEmpty);
    });

    test('unconfigured Core is blocked', () async {
      final result = await const CoreTransferService(null).requeryTransfer(
        const CoreTrackingReference(CoreTransferKind.intrabank, 'a1b2c3d4e5f6'),
      );
      expect(result.status, ServiceStatus.blocked);
    });
  });
}
