import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/core_submission_models.dart';

class CoreSubmissionState<D> extends Equatable {
  const CoreSubmissionState({this.draft, this.inFlight = false, this.outcome});

  /// The draft last sent (or being sent).
  final D? draft;
  final bool inFlight;
  final CoreSubmissionOutcome? outcome;

  @override
  List<Object?> get props => [draft, inFlight, outcome];
}

/// One money-moving POST per draft.
///
/// Core generates every reference and offers no idempotency key, so a
/// request is never repeated automatically: concurrent submits collapse into
/// one, and a draft that was accepted or ended unknown cannot be resent.
/// Only [reset] after a rejection allows the customer to try again.
abstract class CoreSubmissionNotifier<D extends Object>
    extends Notifier<CoreSubmissionState<D>>
    with StaleResultGuard<CoreSubmissionState<D>> {
  /// Sends [draft] to Core.
  Future<ServiceResponse<CoreTransferAck>> send(
    D draft, {
    String? transactionPin,
  });

  @override
  CoreSubmissionState<D> build() {
    trackDisposal();
    return CoreSubmissionState<D>();
  }

  bool _lastSendBlocked = false;

  /// Whether the last [submit] that reached [send] was blocked before any
  /// request left the device (Core not configured), so nothing was judged.
  bool get lastSendBlocked => _lastSendBlocked;

  /// [transactionPin] is passed only to [send], never retained in [state].
  Future<void> submit(D draft, {String? transactionPin}) async {
    if (state.inFlight) return;
    final settled = state.outcome;
    if (state.draft == draft &&
        (settled is AcceptedSubmission || settled is UnknownSubmission)) {
      return;
    }
    final token = beginRequest();
    state = CoreSubmissionState<D>(draft: draft, inFlight: true);
    _lastSendBlocked = false;
    CoreSubmissionOutcome outcome;
    try {
      final stopped = await precheck(draft);
      if (stopped != null) {
        outcome = RejectedSubmission(stopped);
      } else {
        final response = await send(draft, transactionPin: transactionPin);
        _lastSendBlocked = response.status == ServiceStatus.blocked;
        outcome = mapCoreSubmission(response);
      }
    } catch (_) {
      outcome = const UnknownSubmission();
    }
    if (!isCurrent(token)) return;
    state = CoreSubmissionState<D>(draft: draft, outcome: outcome);
    onSettled(outcome);
  }

  /// Why [draft] must not be sent at all, or null to send it. Runs before
  /// [send]; nothing has left the device when it returns a reason.
  Future<CoreRejection?> precheck(D draft) async => null;

  /// Called once for a submitted request whose result still belongs to this
  /// session. Subclasses can refresh related reads after a money movement.
  void onSettled(CoreSubmissionOutcome outcome) {}

  /// Lets the customer try again after a definite rejection.
  void reset() {
    if (state.outcome is RejectedSubmission) {
      state = CoreSubmissionState<D>();
    }
  }

  /// Drops everything, including a late reply, on exit or session change.
  void clear() {
    beginRequest();
    state = CoreSubmissionState<D>();
  }
}
