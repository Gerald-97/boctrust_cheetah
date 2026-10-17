import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_check_progress.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_initiation.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../service/core_transfer_service.dart';
import 'core_account_providers.dart';
import 'core_account_activity_providers.dart';
import 'flex_source_check.dart';

enum CoreTransferPhase {
  /// Reviewed and reserved; initiate is being sent. No money moves.
  initiating,

  /// Core recorded a pending transfer; the PIN sheet is open.
  awaitingPin,
  verifyingPin,

  /// The PIN passed and Core sent an OTP; the OTP sheet is open.
  awaitingOtp,
  verifyingOtp,

  /// Every required check passed; finalize may be sent once.
  readyToFinalize,

  /// Finalize was sent: money may be moving.
  finalizing,
  settled,
}

/// What a PIN or OTP step did. No step moves money.
sealed class CheckStep extends Equatable {
  const CheckStep();

  @override
  List<Object?> get props => [];
}

/// The step passed; the attempt moved to its next phase.
final class CheckPassed extends CheckStep {
  const CheckPassed();
}

/// The step can be tried again on the same initiation, e.g. a wrong PIN.
final class CheckRetry extends CheckStep {
  const CheckRetry(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// The attempt stopped; its outcome says why.
final class CheckStopped extends CheckStep {
  const CheckStopped();
}

/// One reviewed transfer and what happened to it. Holds no credential.
class CoreTransferAttempt extends Equatable {
  const CoreTransferAttempt({
    required this.id,
    required this.draft,
    required this.phase,
    this.initiation,
    this.outcome,
    this.live,
    this.checking = false,
    this.checkError,
  });

  final int id;

  /// A [BoctrustTransferDraft] or [InterbankTransferDraft], exactly as
  /// reviewed.
  final Object draft;
  final CoreTransferPhase phase;

  /// The pending transfer Core recorded. Its reference is never used to
  /// check status; only the final tracking reference is.
  final CoreTransferInitiation? initiation;
  final CoreSubmissionOutcome? outcome;

  /// The latest live BankOne status. Once final it is kept until a reversal
  /// replaces it; a later failed or unclear check never erases it.
  final CoreLiveTransferStatus? live;
  final bool checking;

  /// Why the last check could not confirm a status, shown beside the result.
  final String? checkError;

  CoreTransferKind get kind => draft is InterbankTransferDraft
      ? CoreTransferKind.interbank
      : CoreTransferKind.intrabank;

  /// The identifier Core issued for a live re-query, if it returned one.
  CoreTrackingReference? get tracking => switch (outcome) {
    AcceptedSubmission(:final ack) => ack.trackingReference(kind),
    _ => null,
  };

  /// Whether money may still be moving: in flight, accepted without a final
  /// status, or with no reliable answer at all.
  bool get unresolved => switch (phase) {
    CoreTransferPhase.finalizing => true,
    CoreTransferPhase.settled => switch (outcome) {
      AcceptedSubmission() => !_isFinal(live?.state),
      UnknownSubmission() => true,
      RejectedSubmission() || null => false,
    },
    _ => false,
  };

  CoreTransferAttempt _with({
    required CoreTransferPhase phase,
    CoreTransferInitiation? initiation,
    CoreSubmissionOutcome? outcome,
  }) => CoreTransferAttempt(
    id: id,
    draft: draft,
    phase: phase,
    initiation: initiation ?? this.initiation,
    outcome: outcome,
  );

  CoreTransferAttempt _checked({
    required CoreLiveTransferStatus? live,
    bool checking = false,
    String? checkError,
  }) => CoreTransferAttempt(
    id: id,
    draft: draft,
    phase: phase,
    initiation: initiation,
    outcome: outcome,
    live: live,
    checking: checking,
    checkError: checkError,
  );

  /// This attempt with [status] as its live result.
  CoreTransferAttempt withLive(CoreLiveTransferStatus status) =>
      _checked(live: status);

  @override
  List<Object?> get props => [
    id,
    draft,
    phase,
    initiation,
    outcome,
    live,
    checking,
    checkError,
  ];
}

bool _isFinal(CoreLiveState? state) =>
    state == CoreLiveState.completed ||
    state == CoreLiveState.failed ||
    state == CoreLiveState.reversed;

/// Whether [next] may replace [previous]: a final result is kept unless the
/// money was reversed.
bool _replaces(CoreLiveState? previous, CoreLiveState next) {
  if (!_isFinal(previous)) return true;
  return next == CoreLiveState.reversed && previous != CoreLiveState.reversed;
}

class CoreTransferAttemptState extends Equatable {
  const CoreTransferAttemptState({this.current, this.acknowledged = const []});

  /// The one transfer this session is working on, shared by every transfer
  /// entry so no entry can start a second one while it is unresolved.
  final CoreTransferAttempt? current;

  /// Unresolved transfers the customer chose to set aside, kept visible.
  final List<CoreTransferAttempt> acknowledged;

  @override
  List<Object?> get props => [current, acknowledged];
}

final coreTransferAttemptProvider =
    NotifierProvider<CoreTransferAttemptNotifier, CoreTransferAttemptState>(
      CoreTransferAttemptNotifier.new,
    );

/// Owns every BOCTRUST and interbank transfer for the signed-in customer:
/// initiate, verify the PIN, verify the OTP when Core sends one, finalize
/// once, then track.
///
/// Core offers no idempotency key, so finalize is sent at most once. The PIN
/// and OTP pass straight through [verifyPin] and [verifyOtp] and are never
/// kept; finalize carries no credential.
class CoreTransferAttemptNotifier extends Notifier<CoreTransferAttemptState> {
  int _nextId = 0;

  /// Bumped when the session ends or changes customer, so a late reply is
  /// dropped instead of landing on the next customer.
  int _generation = 0;

  @override
  CoreTransferAttemptState build() {
    ref.listen(authSessionProvider, (previous, next) {
      if (next == null || previous?.userId != next.userId) clear();
    });
    ref.onDispose(() => _generation++);
    return const CoreTransferAttemptState();
  }

  void _set({
    CoreTransferAttempt? current,
    List<CoreTransferAttempt>? acknowledged,
  }) => state = CoreTransferAttemptState(
    current: current,
    acknowledged: acknowledged ?? state.acknowledged,
  );

  /// The attempt in progress, for callers that outlive their widget.
  CoreTransferAttempt? get current => state.current;

  /// Reserves a new attempt for [draft] before initiating. Null when
  /// transfers are not authorized yet or another attempt is open.
  int? beginReview(Object draft) {
    if (!ref.read(transferAuthorizationReadyProvider)) return null;
    if (state.current != null) return null;
    final attempt = CoreTransferAttempt(
      id: ++_nextId,
      draft: draft,
      phase: CoreTransferPhase.initiating,
    );
    _set(current: attempt);
    return attempt.id;
  }

  /// The customer stopped before finalize; no money moved.
  void cancelReview(int id) {
    final current = state.current;
    if (current?.id == id &&
        current?.phase != CoreTransferPhase.finalizing &&
        current?.phase != CoreTransferPhase.settled) {
      _set();
    }
  }

  CoreTransferAttempt? _open(int id, CoreTransferPhase phase) {
    final current = state.current;
    return current != null && current.id == id && current.phase == phase
        ? current
        : null;
  }

  void _settle(CoreTransferAttempt attempt, CoreRejection reason) => _set(
    current: attempt._with(
      phase: CoreTransferPhase.settled,
      outcome: RejectedSubmission(reason),
    ),
  );

  /// Asks Core to record the reviewed transfer and say which checks finalize
  /// needs. A failure here moved no money.
  Future<void> initiate(int id) async {
    final current = _open(id, CoreTransferPhase.initiating);
    if (current == null || !ref.read(transferAuthorizationReadyProvider)) {
      return;
    }
    final generation = _generation;
    // Core debits Boc Flex whatever the app shows, so a fresh read decides
    // before anything is sent; an unconfirmed read counts as frozen.
    final canDebit = await ref.read(freshFlexDebitCheckProvider)();
    if (!ref.mounted ||
        generation != _generation ||
        _open(id, CoreTransferPhase.initiating) == null) {
      return;
    }
    if (!canDebit) return _settle(current, CoreRejection.sourcePaused);
    final service = ref.read(coreTransferServiceProvider);
    final result = await switch (current.draft) {
      final BoctrustTransferDraft d => service.initiateBoctrust(d),
      final InterbankTransferDraft d => service.initiateInterbank(d),
      _ => throw ArgumentError.value(current.draft, 'draft'),
    };
    if (!ref.mounted ||
        generation != _generation ||
        _open(id, CoreTransferPhase.initiating) == null) {
      return;
    }
    final initiation = result.data;
    if (initiation == null) {
      // A 403 explains itself (e.g. Tier 1 verification still needed), so
      // Core's reason is shown instead of generic copy.
      if (result.statusCode == 403) {
        return _set(
          current: current._with(
            phase: CoreTransferPhase.settled,
            outcome: RejectedSubmission(
              CoreRejection.accountRestricted,
              detail: result.message,
            ),
          ),
        );
      }
      return _settle(current, switch (result.statusCode) {
        400 => CoreRejection.validation,
        404 => CoreRejection.accountMissing,
        _ => CoreRejection.initiationFailed,
      });
    }
    if (!initiation.supported) {
      return _settle(
        current._with(phase: current.phase, initiation: initiation),
        CoreRejection.checksUnsupported,
      );
    }
    _set(
      current: current._with(
        phase: CoreTransferPhase.awaitingPin,
        initiation: initiation,
      ),
    );
  }

  /// Verifies the PIN. When the initiation needs an OTP, Core sends it and
  /// the attempt waits for it; otherwise it is ready to finalize. The PIN
  /// passes straight through and is never kept.
  Future<CheckStep> verifyPin(int id, String pin) => _verify(
    id,
    CoreTransferCheck.pin,
    (service, attempt, initiation) =>
        service.verifyTransferPin(attempt.kind, initiation, pin),
  );

  /// Verifies the OTP the customer typed; never kept.
  Future<CheckStep> verifyOtp(int id, String otp) => _verify(
    id,
    CoreTransferCheck.otp,
    (service, attempt, initiation) =>
        service.verifyTransferOtp(attempt.kind, initiation, otp),
  );

  Future<CheckStep> _verify(
    int id,
    CoreTransferCheck step,
    Future<NotifierState<CoreCheckProgress>> Function(
      CoreTransferService service,
      CoreTransferAttempt attempt,
      CoreTransferInitiation initiation,
    )
    send,
  ) async {
    final (waiting, verifying) = step == CoreTransferCheck.pin
        ? (CoreTransferPhase.awaitingPin, CoreTransferPhase.verifyingPin)
        : (CoreTransferPhase.awaitingOtp, CoreTransferPhase.verifyingOtp);
    final current = _open(id, waiting);
    final initiation = current?.initiation;
    if (current == null || initiation == null) return const CheckStopped();
    if (!initiation.supported) {
      _settle(current, CoreRejection.checksUnsupported);
      return const CheckStopped();
    }
    if (initiation.isExpiredAt(DateTime.now())) {
      _settle(current, CoreRejection.initiationExpired);
      return const CheckStopped();
    }
    final generation = _generation;
    _set(current: current._with(phase: verifying));
    final result = await send(
      ref.read(coreTransferServiceProvider),
      current,
      initiation,
    );
    if (!ref.mounted ||
        generation != _generation ||
        _open(id, verifying) == null) {
      return const CheckStopped();
    }
    // Swagger: a 409 on a verify step means it was already completed.
    if (result.isDone || result.statusCode == 409) {
      final pending = result.data?.pending ?? const <CoreTransferCheck>{};
      final contradicts =
          pending.contains(CoreTransferCheck.liveness) ||
          pending.contains(step) ||
          (step == CoreTransferCheck.otp &&
              pending.contains(CoreTransferCheck.pin)) ||
          (step == CoreTransferCheck.pin &&
              !initiation.needsOtp &&
              pending.contains(CoreTransferCheck.otp)) ||
          // Initiate asked for an OTP but the PIN reply no longer awaits one:
          // never open the OTP sheet for a code that was not sent.
          (step == CoreTransferCheck.pin &&
              initiation.needsOtp &&
              result.data != null &&
              !pending.contains(CoreTransferCheck.otp));
      if (contradicts) {
        _settle(current, CoreRejection.checksInconsistent);
        return const CheckStopped();
      }
      _set(
        current: current._with(
          phase: step == CoreTransferCheck.pin && initiation.needsOtp
              ? CoreTransferPhase.awaitingOtp
              : CoreTransferPhase.readyToFinalize,
        ),
      );
      return const CheckPassed();
    }
    if (result.statusCode == 401) {
      _set(current: current._with(phase: waiting));
      return CheckRetry(
        step == CoreTransferCheck.pin
            ? CoreRejection.wrongPin.message
            : 'That code is incorrect or has expired.',
      );
    }
    // Finalize was never sent, so no money moved.
    _settle(current, switch (result.statusCode) {
      400 => CoreRejection.validation,
      403 => CoreRejection.checkRefused,
      404 => CoreRejection.initiationFailed,
      _ => CoreRejection.checkInterrupted,
    });
    return const CheckStopped();
  }

  bool _resending = false;

  /// Asks Core to send the OTP again, on the customer's request. Only once
  /// the PIN is verified and an OTP is awaited; one request at a time.
  Future<CheckStep> resendOtp(int id) async {
    final current = _open(id, CoreTransferPhase.awaitingOtp);
    final initiation = current?.initiation;
    if (current == null || initiation == null) {
      return const CheckRetry('Verify your PIN first.');
    }
    if (_resending) return const CheckRetry('A new code is on its way.');
    _resending = true;
    final generation = _generation;
    try {
      final result = await ref
          .read(coreTransferServiceProvider)
          .resendTransferOtp(current.kind, initiation);
      if (!ref.mounted || generation != _generation) {
        return const CheckStopped();
      }
      if (result.isDone) return const CheckPassed();
      if (result.statusCode == 403) {
        final still = _open(id, CoreTransferPhase.awaitingOtp);
        if (still != null) _settle(still, CoreRejection.checkRefused);
        return const CheckStopped();
      }
      return const CheckRetry("We couldn't send a new code. Try again.");
    } finally {
      _resending = false;
    }
  }

  /// Moves the money: one bodyless finalize once every required check has
  /// passed. Repeated calls while one is in flight send nothing.
  Future<void> finalize(int id) async {
    final current = _open(id, CoreTransferPhase.readyToFinalize);
    final initiation = current?.initiation;
    if (current == null ||
        initiation == null ||
        !ref.read(transferAuthorizationReadyProvider)) {
      return;
    }
    if (initiation.isExpiredAt(DateTime.now())) {
      return _settle(current, CoreRejection.initiationExpired);
    }
    final generation = _generation;
    _set(current: current._with(phase: CoreTransferPhase.finalizing));
    CoreSubmissionOutcome outcome;
    try {
      outcome = mapCoreTransferSubmission(
        await ref
            .read(coreTransferServiceProvider)
            .finalizeTransfer(current.kind, initiation),
      );
    } catch (_) {
      outcome = const UnknownSubmission();
    }
    if (!ref.mounted ||
        generation != _generation ||
        _open(id, CoreTransferPhase.finalizing) == null) {
      return;
    }
    _set(
      current: current._with(
        phase: CoreTransferPhase.settled,
        outcome: outcome,
      ),
    );
    if (outcome is AcceptedSubmission || outcome is UnknownSubmission) {
      ref.read(refreshFlexTransactionHistoryProvider)().ignore();
      ref.read(customerBankAccountsProvider.notifier).load().ignore();
    } else if (outcome case RejectedSubmission(
      reason: CoreRejection.transferRestricted,
    )) {
      // Possibly frozen from another device: let Home show it.
      ref.read(customerBankAccountsProvider.notifier).load().ignore();
    }
  }

  /// Clears a resolved attempt (rejected or final) so a new one can start.
  void startNewTransfer() {
    final current = state.current;
    if (current != null &&
        current.phase == CoreTransferPhase.settled &&
        !current.unresolved) {
      _set();
    }
  }

  /// The customer accepted that [id] may still go through and wants to start
  /// a different transfer. The old attempt stays listed and is never resent.
  void acknowledgeUnresolved(int id) {
    final current = state.current;
    if (current == null ||
        current.id != id ||
        current.phase != CoreTransferPhase.settled ||
        !current.unresolved) {
      return;
    }
    _set(acknowledged: [...state.acknowledged, current]);
  }

  /// Asks BankOne for [id]'s live status: a read that never resends. Works
  /// for the current attempt and for one set aside. Does nothing without a
  /// tracking reference or while a check is already running.
  Future<void> check(int id) async {
    final attempt = _find(id);
    final tracking = attempt?.tracking;
    if (attempt == null || tracking == null || attempt.checking) return;
    final generation = _generation;
    _replace(attempt._checked(live: attempt.live, checking: true));
    final result = await ref
        .read(coreTransferServiceProvider)
        .requeryTransfer(tracking);
    final latest = _find(id);
    if (!ref.mounted || generation != _generation || latest == null) return;
    final previous = latest.live;
    final next = result.data;
    if (next == null) {
      _replace(
        latest._checked(
          live: previous,
          checkError: result.statusCode == 404
              ? "We couldn't find this transfer to check."
              : "We couldn't check this transfer. Try again shortly.",
        ),
      );
      return;
    }
    if (!_replaces(previous?.state, next.state)) {
      _replace(
        latest._checked(
          live: previous,
          checkError: next.state == previous?.state
              ? null
              : "The latest check didn't match the confirmed result.",
        ),
      );
      return;
    }
    _replace(latest._checked(live: next));
    // Balances come from Core only; refresh once when money settles.
    if (next.state == CoreLiveState.completed ||
        next.state == CoreLiveState.reversed) {
      ref.read(customerBankAccountsProvider.notifier).load().ignore();
      ref.read(refreshFlexTransactionHistoryProvider)().ignore();
    }
  }

  CoreTransferAttempt? _find(int id) {
    final current = state.current;
    if (current?.id == id) return current;
    return state.acknowledged.where((a) => a.id == id).firstOrNull;
  }

  void _replace(CoreTransferAttempt attempt) {
    final current = state.current;
    state = CoreTransferAttemptState(
      current: current?.id == attempt.id ? attempt : current,
      acknowledged: [
        for (final a in state.acknowledged) a.id == attempt.id ? attempt : a,
      ],
    );
  }

  /// Drops everything, including a late reply, when the session ends.
  void clear() {
    _generation++;
    state = const CoreTransferAttemptState();
  }
}
