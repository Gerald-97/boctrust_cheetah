import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
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
  'expiresAt': '2099-01-01T00:00:00Z',
};

CoreTransferInitiation _initiation(List<String> checks) =>
    CoreTransferInitiation.fromJson({..._pending, 'requiredChecks': checks});

String? _logged(RequestOptions request) =>
    request.extra[LoggingInterceptor.privacySensitivePathKey] as String?;

void main() {
  // Core documents a Naira decimal amount on both initiate routes.
  test(
    'initiate sends the reviewed fields, a naira amount and no PIN',
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
        'amount': '1650.00',
        'narration': 'rent',
      });
      expect(inter.data, {
        'receiverBankCode': '000014',
        'receiverAccountNumber': '0123456789',
        'amount': '0.01',
      });
      expect(_logged(intra), isNull);
      expect(_logged(inter), isNull);
    },
  );

  test('intrabank amount is sent in Naira up to the documented ceiling', () {
    expect(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '2500000000',
      ).toJson()['amount'],
      '25000000.00',
    );
    expect(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '100',
      ).toJson()['amount'],
      '1.00',
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

  const progress = {
    'reference': 'a1b2c3d4e5f6',
    'requiredChecks': ['pin', 'otp'],
    'completedChecks': ['pin'],
    'pendingChecks': ['otp'],
    'otpSent': true,
    'otpExpiresAt': '2099-01-01T00:05:00Z',
    'otpCode': '123456',
  };

  // Swagger: PIN and OTP go to their own verify routes; resend and finalize
  // have no body.
  test(
    'each check sends only its own credential; finalize sends none',
    () async {
      final core = _Core({
        '/me/interbank/transfers/a1b2c3d4e5f6/pin/verify': progress,
        '/me/interbank/transfers/a1b2c3d4e5f6/otp/resend': progress,
        '/me/interbank/transfers/a1b2c3d4e5f6/otp/verify': {
          ...progress,
          'completedChecks': ['pin', 'otp'],
          'pendingChecks': <String>[],
        },
        '/me/interbank/transfers/a1b2c3d4e5f6/finalize': {
          'transactionReference': 'TX9',
          'status': 'pending',
        },
      });
      final service = _service(core);
      final initiation = _initiation(['pin', 'otp']);
      const kind = CoreTransferKind.interbank;

      final pin = await service.verifyTransferPin(kind, initiation, '0007');
      await service.resendTransferOtp(kind, initiation);
      final otp = await service.verifyTransferOtp(kind, initiation, '654321');
      final ack = await service.finalizeTransfer(kind, initiation);

      final [pinRequest, resend, otpRequest, finalize] = core.requests;
      expect(
        pinRequest.path,
        '/me/interbank/transfers/a1b2c3d4e5f6/pin/verify',
      );
      expect(pinRequest.data, {'transactionPin': '0007'});
      expect(resend.path, '/me/interbank/transfers/a1b2c3d4e5f6/otp/resend');
      expect(resend.data, isNull);
      expect(otpRequest.data, {'otpCode': '654321'});
      expect(finalize.path, '/me/interbank/transfers/a1b2c3d4e5f6/finalize');
      expect(finalize.data, isNull);
      expect(pin.data?.pending, {CoreTransferCheck.otp});
      expect(pin.data?.otpSent, isTrue);
      expect(otp.data?.pending, isEmpty);
      expect(ack.data?.transactionReference, 'TX9');
      // Full staging logs by product decision.
      expect(core.requests.map(_logged), everyElement(isNull));
    },
  );

  test('the staging OTP in a reply is never kept', () async {
    final parsed = CoreCheckProgress.fromJson(progress);

    expect('${parsed.props}', isNot(contains('123456')));
    expect('$parsed', isNot(contains('123456')));
  });

  test('an unknown check in progress is refused', () {
    expect(
      () => CoreCheckProgress.fromJson({
        ...progress,
        'pendingChecks': ['selfie'],
      }),
      throwsFormatException,
    );
  });

  test('a liveness or expired initiation is never sent', () async {
    final core = _Core({});
    final service = _service(core);
    final expired = CoreTransferInitiation(
      reference: 'a1b2c3d4e5f6',
      checks: const {CoreTransferCheck.pin},
      expiresAt: DateTime.utc(2020),
    );

    final liveness = await service.verifyTransferPin(
      CoreTransferKind.intrabank,
      _initiation(['pin', 'liveness']),
      '0007',
    );
    final late = await service.finalizeTransfer(
      CoreTransferKind.intrabank,
      expired,
    );

    expect(liveness.status, ServiceStatus.blocked);
    expect(late.status, ServiceStatus.blocked);
    expect(core.requests, isEmpty);
  });

  test('a failed check or finalize is never retried', () async {
    for (final status in [400, 401, 403, 404, 409, 422, 500, 503]) {
      final core = _Core({}, status: status);
      final service = _service(core);
      final initiation = _initiation(['pin']);

      await service.verifyTransferPin(
        CoreTransferKind.intrabank,
        initiation,
        '0007',
      );
      await service.finalizeTransfer(CoreTransferKind.intrabank, initiation);

      expect(core.requests, hasLength(2), reason: '$status');
    }
  });

  // Staging support needs these replies, the name enquiry included.
  test('status checks and name enquiries are logged in full', () async {
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

    expect(core.requests.map(_logged), [null, null, null, null]);
  });
}
