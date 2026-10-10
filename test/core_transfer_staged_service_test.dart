import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each path with [status] and its canned `data`, recording every
/// request.
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

CoreTransferService _service(_Core core) => CoreTransferService(
  ApiService(
    Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
      ..httpClientAdapter = core,
  ),
);

const _pending = {
  'reference': 'a1b2c3d4e5f6',
  'requiredChecks': ['pin'],
  'expiresAt': '2026-10-10T12:05:00Z',
};

CoreTransferInitiation _initiation(List<String> checks) =>
    CoreTransferInitiation.fromJson({..._pending, 'requiredChecks': checks});

String? _logged(RequestOptions request) =>
    request.extra[LoggingInterceptor.privacySensitivePathKey] as String?;

void main() {
  // Core requires a digit-only Kobo amount on both initiate routes (staging,
  // 10 October: "1650.00 fails to match the required pattern /^\d+$/").
  test(
    'initiate sends the reviewed fields, a Kobo amount and no PIN',
    () async {
      final core = _Core({
        '/me/intrabank/transfers/initiate': _pending,
        '/me/interbank/transfers/initiate': _pending,
      });
      final service = _service(core);

      final boctrust = await service.initiateBoctrust(
        const BoctrustTransferDraft(
          toAccountNumber: '1100037777',
          amountKobo: '165000',
          narration: ' rent ',
        ),
      );
      await service.initiateInterbank(
        const InterbankTransferDraft(
          bankCode: '000014',
          bankName: 'Zenith',
          accountNumber: '0123456789',
          accountName: 'ADA OBI',
          amountKobo: '1',
        ),
      );

      expect(boctrust.data?.reference, 'a1b2c3d4e5f6');
      final [intra, inter] = core.requests;
      expect(intra.data, {
        'toAccountNumber': '1100037777',
        'amount': '165000',
        'narration': 'rent',
      });
      expect(inter.data, {
        'receiverBankCode': '000014',
        'receiverAccountNumber': '0123456789',
        'amount': '1',
      });
      expect(_logged(intra), isNull);
      expect(_logged(inter), isNull);
    },
  );

  test('intrabank amount stays in Kobo up to the documented ceiling', () {
    expect(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '2500000000',
      ).toJson()['amount'],
      '2500000000',
    );
    expect(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '100',
      ).toJson()['amount'],
      '100',
    );
  });

  test('an amount over ₦25,000,000 is never sent', () async {
    final core = _Core({});

    final result = await _service(core).initiateBoctrust(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '2500000001',
      ),
    );

    expect(result.isError, isTrue);
    expect(core.requests, isEmpty);
  });

  test('OTP request and finalize use the encoded reference', () async {
    final core = _Core({
      '/me/interbank/transfers/a1b2c3d4e5f6/finalize': {
        'transactionReference': 'TX9',
        'status': 'pending',
      },
    });
    final service = _service(core);
    final initiation = _initiation(['pin', 'otp']);

    await service.requestTransferOtp(CoreTransferKind.interbank, initiation);
    final ack = await service.finalizeTransfer(
      CoreTransferKind.interbank,
      initiation,
      pin: '0007',
      otp: '123456',
    );

    final [otp, finalize] = core.requests;
    expect(otp.method, 'POST');
    expect(otp.path, '/me/interbank/transfers/a1b2c3d4e5f6/otp/request');
    expect(otp.data, isNull);
    expect(finalize.data, {'transactionPin': '0007', 'otpCode': '123456'});
    expect(_logged(otp), isNull);
    // Finalize carries the PIN and OTP, so its bodies stay redacted.
    expect(_logged(finalize), '/me/interbank/transfers/{reference}/finalize');
    expect(ack.data?.transactionReference, 'TX9');
  });

  test('finalize sends only the checks the initiation asked for', () async {
    final core = _Core({});
    final service = _service(core);

    await service.finalizeTransfer(
      CoreTransferKind.intrabank,
      _initiation(['pin']),
      pin: '0007',
      otp: '123456',
    );
    final missingOtp = await service.finalizeTransfer(
      CoreTransferKind.intrabank,
      _initiation(['pin', 'otp']),
      pin: '0007',
    );
    final liveness = await service.finalizeTransfer(
      CoreTransferKind.intrabank,
      _initiation(['pin', 'liveness']),
      pin: '0007',
    );

    expect(core.requests.single.data, {'transactionPin': '0007'});
    expect(missingOtp.status, ServiceStatus.blocked);
    expect(liveness.status, ServiceStatus.blocked);
  });

  test('a failed finalize is never retried', () async {
    for (final status in [400, 401, 403, 404, 409, 500, 503]) {
      final core = _Core({}, status: status);

      await _service(core).finalizeTransfer(
        CoreTransferKind.intrabank,
        _initiation(['pin']),
        pin: '0007',
      );

      expect(core.requests, hasLength(1), reason: '$status');
    }
  });

  // Staging support needs these replies. The name enquiry stays redacted:
  // Core can return the recipient's BVN.
  test('status checks are logged in full, name enquiries are not', () async {
    final core = _Core({});
    final service = _service(core);

    await service.nameEnquiry(bankCode: '000014', accountNumber: '0123456789');
    await service.getTransferStatus('TX9');
    await service.requeryTransfer(
      const CoreTrackingReference(CoreTransferKind.interbank, 'TX9'),
    );
    await service.requeryTransfer(
      const CoreTrackingReference(CoreTransferKind.intrabank, 'a1b2c3d4e5f6'),
    );

    expect(core.requests.map(_logged), [
      '/me/interbank/name-enquiry',
      null,
      null,
      null,
    ]);
  });
}
