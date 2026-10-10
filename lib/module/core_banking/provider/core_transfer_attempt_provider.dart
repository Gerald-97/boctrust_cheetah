import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_initiation.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../service/core_transfer_service.dart';
import 'core_account_providers.dart';

enum CoreTransferPhase {
  /// Reviewed and reserved; initiate is being sent. No money moves.
  initiating,

  /// Core recorded a pending transfer; the PIN and any OTP are being
  /// collected. No money has moved.
  awaitingChecks,

  /// Finalize was sent: money may be moving.
  finalizing,
  settled,
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
    CoreTransferPhase.initiating || CoreTransferPhase.awaitingChecks => false,
    CoreTransferPhase.finalizing => true,
    CoreTransferPhase.settled => switch (outcome) {
      AcceptedSubmission() => !_isFinal(live?.state),
      UnknownSubmission() => true,
      RejectedSubmission() || null => false,
    },
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
/// initiate, collect the PIN and any OTP, finalize once, then track.
///
/// Core offers no idempotency key, so finalize is sent at most once per
/// credential entry: only a documented wrong-PIN rejection on a still-valid
/// initiation lets it be sent again. The PIN and OTP pass straight through
/// [finalize] and are never kept.
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
        (current?.phase == CoreTransferPhase.initiating ||
            current?.phase == CoreTransferPhase.awaitingChecks)) {
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
        phase: CoreTransferPhase.awaitingChecks,
        initiation: initiation,
      ),
    );
  }

  /// Sends the OTP finalize needs. Returns why it could not be sent, or null.
  Future<String?> requestOtp(int id) async {
    final current = _open(id, CoreTransferPhase.awaitingChecks);
    final initiation = current?.initiation;
    if (current == null || initiation == null || !initiation.needsOtp) {
      return "This transfer doesn't need a code.";
    }
    if (initiation.isExpiredAt(DateTime.now())) {
      _settle(current, CoreRejection.initiationExpired);
      return CoreRejection.initiationExpired.message;
    }
    final result = await ref
        .read(coreTransferServiceProvider)
        .requestTransferOtp(current.kind, initiation);
    return result.isDone ? null : "We couldn't send your code. Try again.";
  }

  /// Moves the money: one finalize with the checks the initiation asked
  /// for. Repeated calls while one is in flight send nothing.
  Future<void> finalize(int id, {required String pin, String? otp}) async {
    final current = _open(id, CoreTransferPhase.awaitingChecks);
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
            .finalizeTransfer(current.kind, initiation, pin: pin, otp: otp),
        interbank: current.kind == CoreTransferKind.interbank,
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
  }

  /// Reopens credential entry after a rejected PIN or OTP, on the same
  /// initiation while it is still valid.
  bool retryPin(int id) {
    final current = _open(id, CoreTransferPhase.settled);
    final initiation = current?.initiation;
    if (current == null ||
        initiation == null ||
        current.outcome != const RejectedSubmission(CoreRejection.wrongPin) ||
        initiation.isExpiredAt(DateTime.now())) {
      return false;
    }
    _set(current: current._with(phase: CoreTransferPhase.awaitingChecks));
    return true;
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
