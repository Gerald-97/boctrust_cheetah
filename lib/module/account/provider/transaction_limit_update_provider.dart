import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../core_banking/model/core_check_progress.dart';
import '../../core_banking/model/core_transfer_initiation.dart';
import '../../core_banking/provider/core_transfer_attempt_provider.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/transaction_limit_update_models.dart';
import '../service/core_transaction_limit_service.dart';
import 'transaction_limit_provider.dart';

enum LimitUpdatePhase {
  idle,
  initiating,
  awaitingPin,
  verifyingPin,
  awaitingOtp,
  verifyingOtp,
  readyToFinalize,
  finalizing,

  /// Core applied the change; the limits were re-read.
  updated,

  /// Stopped before finalize; nothing changed. [LimitUpdateState.message]
  /// says why.
  failed,

  /// Finalize gave no clear answer. The limits were re-read; the change is
  /// never resent automatically.
  unknown,
}

/// One limit change in this session. Holds no PIN or OTP.
class LimitUpdateState extends Equatable {
  const LimitUpdateState({
    this.phase = LimitUpdatePhase.idle,
    this.draft,
    this.initiation,
    this.message,
  });

  final LimitUpdatePhase phase;
  final TransactionLimitDraft? draft;
  final CoreTransferInitiation? initiation;
  final String? message;

  LimitUpdateState _to(LimitUpdatePhase phase, {String? message}) =>
      LimitUpdateState(
        phase: phase,
        draft: draft,
        initiation: initiation,
        message: message,
      );

  @override
  List<Object?> get props => [phase, draft, initiation, message];
}

final transactionLimitUpdateProvider =
    NotifierProvider<TransactionLimitUpdateNotifier, LimitUpdateState>(
      TransactionLimitUpdateNotifier.new,
    );

/// Changes the customer's own limits: initiate, verify the PIN (Core sends
/// the OTP), verify the OTP, then one bodyless finalize. Moves no money, so
/// it is gated by its own capability, not the transfer gate.
class TransactionLimitUpdateNotifier extends Notifier<LimitUpdateState> {
  int _generation = 0;
  bool _resending = false;

  @override
  LimitUpdateState build() {
    ref.listen(authSessionProvider, (previous, next) {
      if (next == null || previous?.userId != next.userId) reset();
    });
    ref.onDispose(() => _generation++);
    return const LimitUpdateState();
  }

  /// Drops the change, including a late reply.
  void reset() {
    _generation++;
    state = const LimitUpdateState();
  }

  bool _live(int generation) => ref.mounted && generation == _generation;

  void _fail(String message) =>
      state = state._to(LimitUpdatePhase.failed, message: message);

  /// Starts a change of [draft]. Not while another change is open or its
  /// outcome is unknown.
  Future<void> start(TransactionLimitDraft draft) async {
    if (state.phase != LimitUpdatePhase.idle &&
        state.phase != LimitUpdatePhase.updated &&
        state.phase != LimitUpdatePhase.failed) {
      return;
    }
    final generation = ++_generation;
    state = LimitUpdateState(phase: LimitUpdatePhase.initiating, draft: draft);
    final result = await ref
        .read(coreTransactionLimitServiceProvider)
        .initiateLimitUpdate(draft);
    if (!_live(generation)) return;
    final initiation = result.data;
    if (initiation == null) {
      return _fail(switch (result.statusCode) {
        400 => "A new limit is above your tier's maximum.",
        403 => 'Verify your identity before changing your limits.',
        _ => result.message ?? "We couldn't start this change.",
      });
    }
    if (!initiation.supported) {
      return _fail("This change needs a check the app can't do yet.");
    }
    state = LimitUpdateState(
      phase: LimitUpdatePhase.awaitingPin,
      draft: draft,
      initiation: initiation,
    );
  }

  /// Verifies the PIN; never kept.
  Future<CheckStep> verifyPin(String pin) => _verify(
    CoreTransferCheck.pin,
    (service, reference) => service.verifyLimitPin(reference, pin),
  );

  /// Verifies the OTP; never kept.
  Future<CheckStep> verifyOtp(String otp) => _verify(
    CoreTransferCheck.otp,
    (service, reference) => service.verifyLimitOtp(reference, otp),
  );

  Future<CheckStep> _verify(
    CoreTransferCheck step,
    Future<NotifierState<CoreCheckProgress>> Function(
      CoreTransactionLimitService service,
      String reference,
    )
    send,
  ) async {
    final (waiting, verifying) = step == CoreTransferCheck.pin
        ? (LimitUpdatePhase.awaitingPin, LimitUpdatePhase.verifyingPin)
        : (LimitUpdatePhase.awaitingOtp, LimitUpdatePhase.verifyingOtp);
    final initiation = state.initiation;
    if (state.phase != waiting || initiation == null) {
      return const CheckStopped();
    }
    if (initiation.isExpiredAt(DateTime.now())) {
      _fail('This change timed out. Start again.');
      return const CheckStopped();
    }
    final generation = _generation;
    state = state._to(verifying);
    final result = await send(
      ref.read(coreTransactionLimitServiceProvider),
      initiation.reference,
    );
    if (!_live(generation) || state.phase != verifying) {
      return const CheckStopped();
    }
    // Swagger: a 409 on a verify step means it was already completed.
    if (result.isDone || result.statusCode == 409) {
      final pending = result.data?.pending ?? const <CoreTransferCheck>{};
      if (pending.contains(step) ||
          pending.contains(CoreTransferCheck.liveness) ||
          (step == CoreTransferCheck.otp &&
              pending.contains(CoreTransferCheck.pin)) ||
          // Initiate asked for an OTP but the PIN reply no longer awaits one.
          (step == CoreTransferCheck.pin &&
              initiation.needsOtp &&
              result.data != null &&
              !pending.contains(CoreTransferCheck.otp))) {
        _fail("We couldn't confirm this change's security checks.");
        return const CheckStopped();
      }
      state = state._to(
        step == CoreTransferCheck.pin && initiation.needsOtp
            ? LimitUpdatePhase.awaitingOtp
            : LimitUpdatePhase.readyToFinalize,
      );
      return const CheckPassed();
    }
    if (result.statusCode == 401) {
      state = state._to(waiting);
      return CheckRetry(
        step == CoreTransferCheck.pin
            ? 'That PIN is incorrect. Please try again.'
            : 'That code is incorrect or has expired.',
      );
    }
    _fail(
      result.statusCode == 403
          ? 'This change expired or your account is locked.'
          : "We couldn't complete the security check. Nothing changed.",
    );
    return const CheckStopped();
  }

  /// Sends the OTP again on the customer's request; one at a time.
  Future<CheckStep> resendOtp() async {
    final initiation = state.initiation;
    if (state.phase != LimitUpdatePhase.awaitingOtp || initiation == null) {
      return const CheckRetry('Verify your PIN first.');
    }
    if (_resending) return const CheckRetry('A new code is on its way.');
    _resending = true;
    try {
      final result = await ref
          .read(coreTransactionLimitServiceProvider)
          .resendLimitOtp(initiation.reference);
      return result.isDone
          ? const CheckPassed()
          : const CheckRetry("We couldn't send a new code. Try again.");
    } finally {
      _resending = false;
    }
  }

  /// Applies the change once; repeated calls while one is in flight send
  /// nothing. Re-reads the limits either way.
  Future<void> finalize() async {
    final initiation = state.initiation;
    if (state.phase != LimitUpdatePhase.readyToFinalize || initiation == null) {
      return;
    }
    final generation = _generation;
    state = state._to(LimitUpdatePhase.finalizing);
    final result = await ref
        .read(coreTransactionLimitServiceProvider)
        .finalizeLimitUpdate(initiation.reference);
    if (!_live(generation)) return;
    ref.invalidate(transactionLimitsProvider);
    if (result.isDone) {
      state = state._to(LimitUpdatePhase.updated);
    } else if (result.statusCode == 400 ||
        result.statusCode == 403 ||
        result.statusCode == 404) {
      _fail(result.message ?? 'Your limits were not changed.');
    } else {
      state = state._to(
        LimitUpdatePhase.unknown,
        message:
            "We couldn't confirm the change. Check your limits before trying "
            'again.',
      );
    }
  }
}
