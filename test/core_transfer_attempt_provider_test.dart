import 'dart:async';

import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

/// Records every send with its PIN and answers from [reply].
class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));

  final pins = <String>[];
  Completer<ServiceResponse<CoreTransferAck>> reply = Completer();

  Future<ServiceResponse<CoreTransferAck>> _send(String pin) {
    pins.add(pin);
    return reply.future;
  }

  @override
  Future<ServiceResponse<CoreTransferAck>> transferToBoctrust(
    BoctrustTransferDraft draft, {
    required String transactionPin,
  }) => _send(transactionPin);

  final queries = <CoreTrackingReference>[];
  final live = <NotifierState<CoreLiveTransferStatus>>[];

  @override
  Future<NotifierState<CoreLiveTransferStatus>> requeryTransfer(
    CoreTrackingReference tracking,
  ) async {
    queries.add(tracking);
    return live.removeAt(0);
  }

  @override
  Future<ServiceResponse<CoreTransferAck>> transferToOtherBank(
    InterbankTransferDraft draft, {
    required String transactionPin,
  }) => _send(transactionPin);
}

const _draft = BoctrustTransferDraft(
  toAccountNumber: '1100037777',
  amountKobo: '1000',
);

const _accepted = ServiceResponse<CoreTransferAck>.success(
  CoreTransferAck(responseCode: '00', retrievalReference: 'a1b2c3d4e5f6'),
  statusCode: 200,
);

ServiceResponse<CoreTransferAck> _error(int status) =>
    ServiceResponse.error('x', statusCode: status);

const _tracking = CoreTrackingReference(
  CoreTransferKind.intrabank,
  'a1b2c3d4e5f6',
);

NotifierState<CoreLiveTransferStatus> _live(CoreLiveState state) =>
    NotifierState.done(
      CoreLiveTransferStatus(state: state, trackingReference: _tracking),
    );

class _Accounts extends CustomerBankAccountsNotifier {
  static var loads = 0;

  @override
  NotifierState<CustomerBankAccountsData> build() => const NotifierState.idle();

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async {
    loads++;
    return state;
  }
}

/// Sends one accepted transfer and returns its attempt ID.
Future<int> _accept(ProviderContainer container, _Transfers transfers) async {
  final notifier = container.read(coreTransferAttemptProvider.notifier);
  final id = notifier.beginReview(_draft)!;
  transfers.reply.complete(_accepted);
  await notifier.submitAuthorized(id, '0007');
  return id;
}

({ProviderContainer container, _Transfers transfers}) _setUp({
  bool ready = true,
}) {
  _Accounts.loads = 0;
  final transfers = _Transfers();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreTransferServiceProvider.overrideWithValue(transfers),
      transferAuthorizationReadyProvider.overrideWithValue(ready),
      customerBankAccountsProvider.overrideWith(_Accounts.new),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, transfers: transfers);
}

void main() {
  test('one reviewed attempt sends its PIN once and never stores it', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    final id = notifier.beginReview(_draft)!;
    expect(notifier.beginReview(_draft), isNull, reason: 'one PIN sheet');
    final first = notifier.submitAuthorized(id, '0007');
    final second = notifier.submitAuthorized(id, '0007');
    transfers.reply.complete(_accepted);
    await Future.wait([first, second]);

    expect(transfers.pins, ['0007']);
    final state = container.read(coreTransferAttemptProvider);
    expect(state.current?.outcome, isA<AcceptedSubmission>());
    expect('$state', isNot(contains('0007')));
  });

  test('cancel sends nothing and frees the reservation', () {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    notifier.cancelReview(notifier.beginReview(_draft)!);

    expect(transfers.pins, isEmpty);
    expect(container.read(coreTransferAttemptProvider).current, isNull);
    expect(notifier.beginReview(_draft), isNotNull);
  });

  test('a wrong PIN can be corrected on the same attempt', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    final id = notifier.beginReview(_draft)!;

    transfers.reply.complete(_error(401));
    await notifier.submitAuthorized(id, '1111');
    expect(
      container.read(coreTransferAttemptProvider).current?.outcome,
      const RejectedSubmission(CoreRejection.wrongPin),
    );

    expect(notifier.retryPin(id), isTrue);
    transfers.reply = Completer()..complete(_accepted);
    await notifier.submitAuthorized(id, '0007');
    expect(transfers.pins, ['1111', '0007']);
  });

  test('an unresolved attempt blocks a new one until acknowledged', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    final id = notifier.beginReview(_draft)!;
    transfers.reply.complete(_accepted);
    await notifier.submitAuthorized(id, '0007');

    expect(notifier.beginReview(_draft), isNull);
    notifier.startNewTransfer();
    expect(container.read(coreTransferAttemptProvider).current?.id, id);

    notifier.acknowledgeUnresolved(id);
    final state = container.read(coreTransferAttemptProvider);
    expect(state.current, isNull);
    expect(state.acknowledged.single.id, id);
    expect(notifier.beginReview(_draft), isNot(id));
  });

  test('a definite rejection allows a new transfer', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    final id = notifier.beginReview(_draft)!;
    transfers.reply.complete(_error(409));
    await notifier.submitAuthorized(id, '0007');

    expect(
      container.read(coreTransferAttemptProvider).current?.outcome,
      const RejectedSubmission(CoreRejection.possibleDuplicate),
    );
    expect(notifier.retryPin(id), isFalse);
    notifier.startNewTransfer();
    expect(notifier.beginReview(_draft), isNotNull);
  });

  test('signing out drops the attempt and ignores a late reply', () async {
    final (:container, :transfers) = _setUp();
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    final id = notifier.beginReview(_draft)!;
    final pending = notifier.submitAuthorized(id, '0007');

    container.read(authSessionProvider.notifier).clear();
    transfers.reply.complete(_accepted);
    await pending;

    final state = container.read(coreTransferAttemptProvider);
    expect(state.current, isNull);
    expect(state.acknowledged, isEmpty);
  });

  test('nothing is sent while authorization is not ready', () async {
    final (:container, :transfers) = _setUp(ready: false);
    final notifier = container.read(coreTransferAttemptProvider.notifier);

    expect(notifier.beginReview(_draft), isNull);
    expect(transfers.pins, isEmpty);
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

  group('live status', () {
    test('a completed check resolves the attempt and refreshes balances '
        'once', () async {
      final (:container, :transfers) = _setUp();
      final notifier = container.read(coreTransferAttemptProvider.notifier);
      final id = await _accept(container, transfers);

      transfers.live
        ..add(_live(CoreLiveState.completed))
        ..add(_live(CoreLiveState.completed));
      await Future.wait([notifier.check(id), notifier.check(id)]);
      await notifier.check(id);

      expect(transfers.queries, [_tracking, _tracking]);
      expect(_Accounts.loads, 1);
      final current = container.read(coreTransferAttemptProvider).current!;
      expect(current.live?.state, CoreLiveState.completed);
      expect(current.unresolved, isFalse);
      notifier.startNewTransfer();
      expect(container.read(coreTransferAttemptProvider).current, isNull);
    });

    test('a later unknown or failed check never erases a confirmed result, '
        'but a reversal does', () async {
      final (:container, :transfers) = _setUp();
      final notifier = container.read(coreTransferAttemptProvider.notifier);
      final id = await _accept(container, transfers);
      CoreLiveState? state() =>
          container.read(coreTransferAttemptProvider).current?.live?.state;

      transfers.live.addAll([
        _live(CoreLiveState.completed),
        _live(CoreLiveState.unknown),
        const NotifierState.error('Down', statusCode: 500),
        _live(CoreLiveState.reversed),
      ]);
      await notifier.check(id);
      await notifier.check(id);
      expect(state(), CoreLiveState.completed);
      await notifier.check(id);
      expect(state(), CoreLiveState.completed);
      expect(
        container.read(coreTransferAttemptProvider).current?.checkError,
        isNotNull,
      );
      await notifier.check(id);
      expect(state(), CoreLiveState.reversed);
      expect(_Accounts.loads, 2);
    });

    test('without a tracking reference nothing is queried', () async {
      final (:container, :transfers) = _setUp();
      final notifier = container.read(coreTransferAttemptProvider.notifier);
      final id = notifier.beginReview(_draft)!;
      transfers.reply.complete(
        const ServiceResponse.success(
          CoreTransferAck(responseCode: '00', reference: 'R1'),
          statusCode: 200,
        ),
      );
      await notifier.submitAuthorized(id, '0007');

      await notifier.check(id);
      expect(transfers.queries, isEmpty);
    });
  });
}
