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
  Future<ServiceResponse<CoreTransferAck>> send(D draft);

  @override
  CoreSubmissionState<D> build() {
    trackDisposal();
    return CoreSubmissionState<D>();
  }

  Future<void> submit(D draft) async {
    if (state.inFlight) return;
    final settled = state.outcome;
    if (state.draft == draft &&
        (settled is AcceptedSubmission || settled is UnknownSubmission)) {
      return;
    }
    final token = beginRequest();
    state = CoreSubmissionState<D>(draft: draft, inFlight: true);
    CoreSubmissionOutcome outcome;
    try {
      outcome = mapCoreSubmission(await send(draft));
    } catch (_) {
      outcome = const UnknownSubmission();
    }
    if (!isCurrent(token)) return;
    state = CoreSubmissionState<D>(draft: draft, outcome: outcome);
  }

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
