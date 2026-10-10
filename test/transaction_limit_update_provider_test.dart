import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_models.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_update_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/transaction_limit_update_provider.dart';
import 'package:boctrust_savings_loan/module/account/service/core_transaction_limit_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

const _draft = TransactionLimitDraft(dailyTransferLimit: '5000000');

NotifierState<CoreCheckProgress> _ok([List<String> pending = const []]) =>
    NotifierState.done(
      CoreCheckProgress(
        reference: 'a1b2c3d4e5f6',
        pending: {for (final c in pending) CoreTransferCheck.parse(c)!},
      ),
    );

class _Limits extends CoreTransactionLimitService {
  _Limits() : super(null);

  NotifierState<CoreTransferInitiation> initiation = NotifierState.done(
    CoreTransferInitiation(
      reference: 'a1b2c3d4e5f6',
      checks: const {CoreTransferCheck.pin, CoreTransferCheck.otp},
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    ),
  );
  final pinReplies = <NotifierState<CoreCheckProgress>>[];
  final otpReplies = <NotifierState<CoreCheckProgress>>[];
  NotifierState<bool> finalizeReply = const NotifierState.done(true);
  final pins = <String>[];
  var finalized = 0;
  var reads = 0;

  @override
  Future<NotifierState<TransactionLimits>> getLimits() async {
    reads++;
    return const NotifierState.error('unused', statusCode: 500);
  }

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateLimitUpdate(
    TransactionLimitDraft draft,
  ) async => initiation;

  @override
  Future<NotifierState<CoreCheckProgress>> verifyLimitPin(
    String reference,
    String pin,
  ) async {
    pins.add(pin);
    return pinReplies.isEmpty ? _ok(['otp']) : pinReplies.removeAt(0);
  }

  @override
  Future<NotifierState<CoreCheckProgress>> verifyLimitOtp(
    String reference,
    String otp,
  ) async => otpReplies.isEmpty ? _ok() : otpReplies.removeAt(0);

  @override
  Future<NotifierState<bool>> finalizeLimitUpdate(String reference) async {
    finalized++;
    return finalizeReply;
  }
}

({ProviderContainer container, _Limits limits}) _setUp() {
  final limits = _Limits();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreTransactionLimitServiceProvider.overrideWithValue(limits),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, limits: limits);
}

LimitUpdatePhase _phase(ProviderContainer c) =>
    c.read(transactionLimitUpdateProvider).phase;

void main() {
  test('PIN, then OTP, then one finalize and a fresh read', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);

    await notifier.start(_draft);
    expect(_phase(container), LimitUpdatePhase.awaitingPin);
    expect(await notifier.verifyPin('0007'), const CheckPassed());
    expect(_phase(container), LimitUpdatePhase.awaitingOtp);
    expect(await notifier.verifyOtp('123456'), const CheckPassed());
    await Future.wait([notifier.finalize(), notifier.finalize()]);

    expect(limits.finalized, 1);
    expect(_phase(container), LimitUpdatePhase.updated);
    expect(
      '${container.read(transactionLimitUpdateProvider)}',
      isNot(contains('0007')),
    );
  });

  test('a PIN reply without the expected OTP stops the change', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);
    limits.pinReplies.add(_ok());

    await notifier.start(_draft);

    expect(await notifier.verifyPin('0007'), const CheckStopped());
    expect(_phase(container), LimitUpdatePhase.failed);
  });

  test('a wrong PIN stays on the PIN step', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);
    limits.pinReplies.add(const NotifierState.error('x', statusCode: 401));

    await notifier.start(_draft);

    expect(await notifier.verifyPin('0000'), isA<CheckRetry>());
    expect(_phase(container), LimitUpdatePhase.awaitingPin);
  });

  test('an already-completed OTP step goes on to finalize', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);
    limits.otpReplies.add(const NotifierState.error('x', statusCode: 409));

    await notifier.start(_draft);
    await notifier.verifyPin('0007');

    expect(await notifier.verifyOtp('123456'), const CheckPassed());
    expect(_phase(container), LimitUpdatePhase.readyToFinalize);
  });

  test('an uncertain finalize is never retried or called a success', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);
    limits.finalizeReply = const NotifierState.error('x', statusCode: 500);

    await notifier.start(_draft);
    await notifier.verifyPin('0007');
    await notifier.verifyOtp('123456');
    await notifier.finalize();
    await notifier.finalize();

    expect(limits.finalized, 1);
    expect(_phase(container), LimitUpdatePhase.unknown);
  });

  test('a value above the tier ceiling stops before any check', () async {
    final (:container, :limits) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);
    limits.initiation = const NotifierState.error(
      'A requested value exceeds the tier ceiling.',
      statusCode: 400,
    );

    await notifier.start(_draft);
    await notifier.verifyPin('0007');

    expect(limits.pins, isEmpty);
    expect(_phase(container), LimitUpdatePhase.failed);
  });

  test('signing out clears the change', () async {
    final (:container, limits: _) = _setUp();
    final notifier = container.read(transactionLimitUpdateProvider.notifier);

    await notifier.start(_draft);
    await container.read(authSessionProvider.notifier).clear();

    expect(_phase(container), LimitUpdatePhase.idle);
  });
}
