import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../service/core_transfer_service.dart';

enum CoreTransferPhase {
  /// Reviewed and reserved; the PIN sheet is open. Nothing has been sent.
  authorizing,
  submitting,
  settled,
}

/// One reviewed transfer and what happened to it. Holds no credential.
class CoreTransferAttempt extends Equatable {
  const CoreTransferAttempt({
    required this.id,
    required this.draft,
    required this.phase,
    this.outcome,
  });

  final int id;

  /// An [OwnAccountMoveDraft], [BoctrustTransferDraft] or
  /// [InterbankTransferDraft], exactly as reviewed.
  final Object draft;
  final CoreTransferPhase phase;
  final CoreSubmissionOutcome? outcome;

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
    CoreTransferPhase.authorizing => false,
    CoreTransferPhase.submitting => true,
    CoreTransferPhase.settled => switch (outcome) {
      AcceptedSubmission() || UnknownSubmission() => true,
      RejectedSubmission() || null => false,
    },
  };

  CoreTransferAttempt _with({
    required CoreTransferPhase phase,
    CoreSubmissionOutcome? outcome,
  }) =>
      CoreTransferAttempt(id: id, draft: draft, phase: phase, outcome: outcome);

  @override
  List<Object?> get props => [id, draft, phase, outcome];
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

/// Owns every own-account move, withdrawal, BOCTRUST and interbank transfer
/// for the signed-in customer.
///
/// Core generates every reference and offers no idempotency key, so a
/// reviewed attempt is sent at most once per PIN entry: only a documented
/// wrong-PIN rejection lets the same attempt be sent again. The PIN passes
/// straight through [submitAuthorized] and is never kept.
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

  /// Reserves a new attempt for [draft] before the PIN sheet opens. Null
  /// when transfers are not authorized yet or another attempt is open.
  int? beginReview(Object draft) {
    if (!ref.read(transferAuthorizationReadyProvider)) return null;
    if (state.current != null) return null;
    final attempt = CoreTransferAttempt(
      id: ++_nextId,
      draft: draft,
      phase: CoreTransferPhase.authorizing,
    );
    _set(current: attempt);
    return attempt.id;
  }

  /// The customer closed the PIN sheet; nothing was sent.
  void cancelReview(int id) {
    final current = state.current;
    if (current?.id == id && current?.phase == CoreTransferPhase.authorizing) {
      _set();
    }
  }

  /// Reopens PIN entry after a rejected PIN, on the same reviewed attempt.
  bool retryPin(int id) {
    final current = state.current;
    if (current == null ||
        current.id != id ||
        current.outcome != const RejectedSubmission(CoreRejection.wrongPin)) {
      return false;
    }
    _set(current: current._with(phase: CoreTransferPhase.authorizing));
    return true;
  }

  Future<void> submitAuthorized(int id, String transactionPin) async {
    final current = state.current;
    if (!ref.read(transferAuthorizationReadyProvider) ||
        current == null ||
        current.id != id ||
        current.phase != CoreTransferPhase.authorizing) {
      return;
    }
    final generation = _generation;
    _set(current: current._with(phase: CoreTransferPhase.submitting));
    CoreSubmissionOutcome outcome;
    try {
      outcome = mapCoreTransferSubmission(
        await _send(current.draft, transactionPin),
        interbank: current.kind == CoreTransferKind.interbank,
      );
    } catch (_) {
      outcome = const UnknownSubmission();
    }
    if (!ref.mounted || generation != _generation || state.current?.id != id) {
      return;
    }
    _set(
      current: current._with(
        phase: CoreTransferPhase.settled,
        outcome: outcome,
      ),
    );
  }

  Future<ServiceResponse<CoreTransferAck>> _send(Object draft, String pin) {
    final service = ref.read(coreTransferServiceProvider);
    return switch (draft) {
      final OwnAccountMoveDraft d => service.moveBetweenOwnAccounts(
        d,
        transactionPin: pin,
      ),
      final BoctrustTransferDraft d => service.transferToBoctrust(
        d,
        transactionPin: pin,
      ),
      final InterbankTransferDraft d => service.transferToOtherBank(
        d,
        transactionPin: pin,
      ),
      _ => throw ArgumentError.value(draft, 'draft', 'Not a transfer draft'),
    };
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

  /// Drops everything, including a late reply, when the session ends.
  void clear() {
    _generation++;
    state = const CoreTransferAttemptState();
  }
}
