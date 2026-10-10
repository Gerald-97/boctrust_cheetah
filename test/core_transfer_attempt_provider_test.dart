import 'dart:async';

import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
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

/// Answers initiate from [initiation] and finalize from [reply], recording
/// what was sent.
class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));

  NotifierState<CoreTransferInitiation> initiation = _initiated(['pin']);
  Completer<ServiceResponse<CoreTransferAck>> reply = Completer();
  final finalized = <({String pin, String? otp})>[];
  var otpRequests = 0;
  final live = <NotifierState<CoreLiveTransferStatus>>[];

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateBoctrust(
    BoctrustTransferDraft draft,
  ) async => initiation;

  @override
  Future<NotifierState<bool>> requestTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    otpRequests++;
    return const NotifierState.done(true);
  }

  @override
  Future<ServiceResponse<CoreTransferAck>> finalizeTransfer(
    CoreTransferKind kind,
    CoreTransferInitiation initiation, {
    required String pin,
    String? otp,
  }) {
    finalized.add((pin: pin, otp: otp));
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

/// Reserves and initiates [_draft]; returns the attempt ID.
Future<int> _initiate(ProviderContainer container) async {
  final notifier = container.read(coreTransferAttemptProvider.notifier);
  final id = notifier.beginReview(_draft)!;
  await notifier.initiate(id);
  return id;
}

void main() {
  test('PIN only: initiate, then one finalize with the PIN', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    expect(_current(container)?.phase, CoreTransferPhase.awaitingChecks);

    transfers.reply.complete(_accepted);
    await Future.wait([
      notifier.finalize(id, pin: '0007'),
      notifier.finalize(id, pin: '0007'),
    ]);

    expect(transfers.finalized, [(pin: '0007', otp: null)]);
    expect(transfers.otpRequests, 0);
    expect(_current(container)?.phase, CoreTransferPhase.settled);
    expect(_current(container)?.outcome, isA<AcceptedSubmission>());
    expect('${_current(container)?.props}', isNot(contains('0007')));
  });

  test('PIN and OTP: the OTP is requested, then sent with the PIN', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'otp']);

    final id = await _initiate(container);
    expect(await notifier.requestOtp(id), isNull);
    transfers.reply.complete(_accepted);
    await notifier.finalize(id, pin: '0007', otp: '123456');

    expect(transfers.otpRequests, 1);
    expect(transfers.finalized, [(pin: '0007', otp: '123456')]);
  });

  test('another transfer cannot start while one is open', () async {
    final (:container, transfers: _) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    await _initiate(container);

    expect(notifier.beginReview(_draft), isNull);
  });

  test('a liveness check stops the transfer before finalize', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    transfers.initiation = _initiated(['pin', 'liveness']);

    final id = await _initiate(container);
    await notifier.finalize(id, pin: '0007');

    expect(transfers.finalized, isEmpty);
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
    await notifier.finalize(id, pin: '0007');

    expect(transfers.finalized, isEmpty);
    expect(
      _current(container)?.outcome,
      const RejectedSubmission(CoreRejection.initiationExpired),
    );
  });

  test('a wrong PIN can be corrected on the same initiation', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    transfers.reply.complete(_error(401));
    await notifier.finalize(id, pin: '0000');

    expect(notifier.retryPin(id), isTrue);
    expect(_current(container)?.phase, CoreTransferPhase.awaitingChecks);
    transfers.reply = Completer()..complete(_accepted);
    await notifier.finalize(id, pin: '0007');
    expect(transfers.finalized.map((f) => f.pin), ['0000', '0007']);
  });

  test('an unknown outcome stays open until set aside', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    transfers.reply.complete(_error(503));
    await notifier.finalize(id, pin: '0007');

    expect(_current(container)?.outcome, const UnknownSubmission());
    expect(_current(container)?.unresolved, isTrue);
    notifier.startNewTransfer();
    expect(notifier.beginReview(_draft), isNull);
    notifier.acknowledgeUnresolved(id);
    expect(notifier.beginReview(_draft), isNotNull);
    expect(transfers.finalized, hasLength(1));
  });

  test('signing out drops the attempt and ignores a late reply', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = await _initiate(container);
    final pending = notifier.finalize(id, pin: '0007');
    await container.read(authSessionProvider.notifier).clear();
    transfers.reply.complete(_accepted);
    await pending;

    expect(_current(container), isNull);
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
    transfers.reply.complete(_accepted);
    await notifier.finalize(id, pin: '0007');
    await notifier.check(id);
    await notifier.check(id);

    expect(_current(container)?.live?.state, CoreLiveState.completed);
    expect(_current(container)?.unresolved, isFalse);
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

  test('the documented transfer errors map per the Core docs', () {
    CoreSubmissionOutcome map(
      ServiceResponse<CoreTransferAck> r, {
      bool interbank = false,
    }) => mapCoreTransferSubmission(r, interbank: interbank);

    expect(map(_error(401)), const RejectedSubmission(CoreRejection.wrongPin));
    expect(
      map(_error(403)),
      const RejectedSubmission(CoreRejection.transferRestricted),
    );
    expect(
      map(_error(409)),
      const RejectedSubmission(CoreRejection.possibleDuplicate),
    );
    expect(
      map(_error(500), interbank: true),
      const RejectedSubmission(CoreRejection.recipientUnresolved),
    );
    expect(map(_error(503)), const UnknownSubmission());
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
