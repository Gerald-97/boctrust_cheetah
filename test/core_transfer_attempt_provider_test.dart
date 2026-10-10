import 'dart:async';

import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

const _draft = BoctrustTransferDraft(
  toAccountNumber: '1100037777',
  amountKobo: '1000',
);

NotifierState<CoreTransferInitiation> _initiated(
  List<String> checks, {
  Duration expiresIn = const Duration(minutes: 5),
}) => NotifierState.done(
  CoreTransferInitiation(
    reference: 'a1b2c3d4e5f6',
    checks: {for (final c in checks) CoreTransferCheck.parse(c)!},
    expiresAt: DateTime.now().toUtc().add(expiresIn),
  ),
);

const _accepted = ServiceResponse<CoreTransferAck>.success(
  CoreTransferAck(responseCode: '00', retrievalReference: 'a1b2c3d4e5f6'),
  statusCode: 200,
);

ServiceResponse<CoreTransferAck> _error(int status) =>
    ServiceResponse.error('x', statusCode: status);

NotifierState<CoreCheckProgress> _progress({
  List<String> pending = const [],
  int? status,
}) => status != null
    ? NotifierState.error('x', statusCode: status)
    : NotifierState.done(
        CoreCheckProgress(
          reference: 'a1b2c3d4e5f6',
          pending: {for (final c in pending) CoreTransferCheck.parse(c)!},
        ),
      );

/// Answers initiate, each check and finalize from canned replies, recording
/// what was sent.
class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));

  NotifierState<CoreTransferInitiation> initiation = _initiated(['pin']);
  final pinReplies = <NotifierState<CoreCheckProgress>>[];
  final otpReplies = <NotifierState<CoreCheckProgress>>[];
  Completer<ServiceResponse<CoreTransferAck>> reply = Completer();
  final pins = <String>[];
  final otps = <String>[];
  var resends = 0;
  var finalized = 0;
  final live = <NotifierState<CoreLiveTransferStatus>>[];

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateBoctrust(
    BoctrustTransferDraft draft,
  ) async => initiation;

  @override
  Future<NotifierState<CoreCheckProgress>> verifyTransferPin(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String pin,
  ) async {
    pins.add(pin);
    return pinReplies.isEmpty ? _progress() : pinReplies.removeAt(0);
  }

  @override
  Future<NotifierState<CoreCheckProgress>> resendTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    resends++;
    return _progress(pending: ['otp']);
  }

  @override
  Future<NotifierState<CoreCheckProgress>> verifyTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String otp,
  ) async {
    otps.add(otp);
    return otpReplies.isEmpty ? _progress() : otpReplies.removeAt(0);
  }

  @override
  Future<ServiceResponse<CoreTransferAck>> finalizeTransfer(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) {
    finalized++;
    return reply.future;
  }

  @override
  Future<NotifierState<CoreLiveTransferStatus>> requeryTransfer(
    CoreTrackingReference tracking,
  ) async => live.removeAt(0);
}

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => const NotifierState.idle();

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

({ProviderContainer container, _Transfers transfers}) _setUp({
  bool ready = true,
}) {
  final transfers = _Transfers();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      transferAuthorizationReadyProvider.overrideWithValue(ready),
      coreTransferServiceProvider.overrideWithValue(transfers),
      customerBankAccountsProvider.overrideWith(_Accounts.new),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, transfers: transfers);
}

CoreTransferAttempt? _current(ProviderContainer container) =>
    container.read(coreTransferAttemptProvider).current;

CoreTransferPhase? _phase(ProviderContainer container) =>
    _current(container)?.phase;

/// Reserves and initiates [_draft]; returns the attempt ID.
Future<int> _initiate(ProviderContainer container) async {
  final notifier = container.read(coreTransferAttemptProvider.notifier);
  final id = notifier.beginReview(_draft)!;
  await notifier.initiate(id);
  return id;
}

void main() {
  test('PIN only: verify the PIN, then one bodyless finalize', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    expect(_phase(container), CoreTransferPhase.awaitingPin);
    expect(await notifier.verifyPin(id, '0007'), const CheckPassed());
    expect(_phase(container), CoreTransferPhase.readyToFinalize);

    transfers.reply.complete(_accepted);
    await Future.wait([notifier.finalize(id), notifier.finalize(id)]);

    expect(transfers.pins, ['0007']);
    expect(transfers.finalized, 1);
    expect(_phase(container), CoreTransferPhase.settled);
    expect(_current(container)?.outcome, isA<AcceptedSubmission>());
    expect('${_current(container)?.props}', isNot(contains('0007')));
  });

  test('PIN then OTP: finalize only after the OTP is verified', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);
    transfers.pinReplies.add(_progress(pending: ['otp']));

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    expect(_phase(container), CoreTransferPhase.awaitingOtp);
    await notifier.finalize(id);
    expect(transfers.finalized, 0);

    expect(await notifier.verifyOtp(id, '123456'), const CheckPassed());
    transfers.reply.complete(_accepted);
    await notifier.finalize(id);

    expect(transfers.otps, ['123456']);
    expect(transfers.finalized, 1);
  });

  test('a resend is only sent after the PIN is verified', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);
    transfers.pinReplies.add(_progress(pending: ['otp']));

    final id = await _initiate(container);
    expect(await notifier.resendOtp(id), isA<CheckRetry>());
    expect(transfers.resends, 0);
    await notifier.verifyPin(id, '0007');
    expect(await notifier.resendOtp(id), const CheckPassed());

    expect(transfers.resends, 1);
  });

  test('a wrong PIN or OTP stays on its own step', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);
    transfers.pinReplies.addAll([
      _progress(status: 401),
      _progress(pending: ['otp']),
    ]);
    transfers.otpReplies.add(_progress(status: 401));

    final id = await _initiate(container);
    expect(await notifier.verifyPin(id, '0000'), isA<CheckRetry>());
    expect(_phase(container), CoreTransferPhase.awaitingPin);
    await notifier.verifyPin(id, '0007');
    expect(await notifier.verifyOtp(id, '000000'), isA<CheckRetry>());

    expect(_phase(container), CoreTransferPhase.awaitingOtp);
    expect(notifier.beginReview(_draft), isNull);
  });

  // Swagger: a 409 on a verify step means it was already completed.
  test('an already-completed PIN step goes on to finalize once', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.pinReplies.add(_progress(status: 409));

    final id = await _initiate(container);
    expect(await notifier.verifyPin(id, '0007'), const CheckPassed());
    transfers.reply.complete(_accepted);
    await notifier.finalize(id);

    expect(transfers.finalized, 1);
  });

  test('an already-completed OTP step goes on to finalize once', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);
    transfers.pinReplies.add(_progress(pending: ['otp']));
    transfers.otpReplies.add(_progress(status: 409));

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    expect(await notifier.verifyOtp(id, '123456'), const CheckPassed());
    transfers.reply.complete(_accepted);
    await notifier.finalize(id);

    expect(transfers.finalized, 1);
  });

  test('a reply still pending a done step stops the transfer', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);
    transfers.pinReplies.add(_progress(pending: ['otp']));
    transfers.otpReplies.add(_progress(pending: ['otp']));

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    expect(await notifier.verifyOtp(id, '123456'), const CheckStopped());
    await notifier.finalize(id);

    expect(transfers.finalized, 0);
    expect(_current(container)?.outcome, isA<RejectedSubmission>());
  });

  test('a liveness check stops before any check is sent', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'liveness']);

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');

    expect(transfers.pins, isEmpty);
    expect(
      _current(container)?.outcome,
      const RejectedSubmission(CoreRejection.checksUnsupported),
    );
  });

  test('an expired initiation is never finalized', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated([
      'pin',
    ], expiresIn: const Duration(seconds: -1));

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    await notifier.finalize(id);

    expect(transfers.pins, isEmpty);
    expect(transfers.finalized, 0);
    expect(
      _current(container)?.outcome,
      const RejectedSubmission(CoreRejection.initiationExpired),
    );
  });

  test('signing out drops the attempt and ignores a late reply', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    final pending = notifier.finalize(id);
    await container.read(authSessionProvider.notifier).clear();
    transfers.reply.complete(_accepted);
    await pending;

    expect(_current(container), isNull);
  });

  test('cancel before finalize frees the reservation', () async {
    final (:container, transfers: _) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    notifier.cancelReview(await _initiate(container));

    expect(notifier.beginReview(_draft), isNotNull);
  });

  test('no attempt starts while authorization is not ready', () {
    final (:container, transfers: _) = _setUp(ready: false);

    expect(
      container.read(coreTransferAttemptProvider.notifier).beginReview(_draft),
      isNull,
    );
  });

  test('a confirmed result is kept when a later check fails', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    const tracking = CoreTrackingReference(
      CoreTransferKind.intrabank,
      'a1b2c3d4e5f6',
    );
    transfers.live.addAll([
      const NotifierState.done(
        CoreLiveTransferStatus(
          state: CoreLiveState.completed,
          trackingReference: tracking,
        ),
      ),
      const NotifierState.error('down', statusCode: 503),
    ]);

    final id = await _initiate(container);
    await notifier.verifyPin(id, '0007');
    transfers.reply.complete(_accepted);
    await notifier.finalize(id);
    await notifier.check(id);
    await notifier.check(id);

    expect(_current(container)?.live?.state, CoreLiveState.completed);
    expect(_current(container)?.unresolved, isFalse);
  });
  // Swagger finalize: 403 restricted/expired, 422 declined by the bank,
  // 409 similar or already processing, 500 BankOne unreachable.
  test('finalize errors map per the Swagger', () {
    CoreSubmissionOutcome map(ServiceResponse<CoreTransferAck> r) =>
        mapCoreTransferSubmission(r);

    expect(
      map(_error(403)),
      const RejectedSubmission(CoreRejection.transferRestricted),
    );
    expect(
      map(
        const ServiceResponse.error(
          'Beneficiary account is dormant',
          statusCode: 422,
        ),
      ),
      const RejectedSubmission(
        CoreRejection.bankDeclined,
        detail: 'Beneficiary account is dormant',
      ),
    );
    // Neither may claim that nothing moved, nor invite a retry.
    for (final status in [409, 500, 503]) {
      expect(map(_error(status)), const UnknownSubmission(), reason: '$status');
    }
    expect(
      map(
        const ServiceResponse.error(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
          errorCode: kLocalSessionExpiredCode,
        ),
      ),
      const RejectedSubmission(CoreRejection.sessionExpired),
    );
  });
}
