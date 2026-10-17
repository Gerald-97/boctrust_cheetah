import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../core_banking/provider/core_account_providers.dart';
import '../../core_banking/provider/core_account_activity_providers.dart';
import '../model/savings_plan_models.dart';
import '../service/core_savings_plan_service.dart';
import 'savings_plan_provider.dart';

/// Where a plan action stands. [unknown] means Core may or may not have
/// applied it (no response, a 5xx, or a reply that could not be read).
enum SavingsPlanActionPhase { idle, sending, done, failed, unknown }

/// Which flow started an action; one flow never shows another's state.
enum SavingsPlanAction { fund, liquidate, create }

/// Shown when a flow starts while another flow's action is still sending.
const savingsPlanBusyMessage =
    'Another savings action is still in progress. Try again in a moment.';

class SavingsPlanActionState extends Equatable {
  const SavingsPlanActionState({
    this.phase = SavingsPlanActionPhase.idle,
    this.action,
    this.requestedPlanId,
    this.planId,
    this.result,
    this.message,
  });

  final SavingsPlanActionPhase phase;

  /// The flow that started this state; null when idle.
  final SavingsPlanAction? action;

  /// The plan the flow asked about; null for [SavingsPlanAction.create].
  final String? requestedPlanId;

  /// The plan the action touched, set once Core confirms it.
  final String? planId;
  final SavingsPlanActionResult? result;
  final String? message;

  /// Whether the flow for [kind] on [planId] started this state.
  bool startedBy(SavingsPlanAction kind, [String? planId]) =>
      action == kind && requestedPlanId == planId;

  /// What the flow for [kind] on [planId] shows: this state when it started
  /// it, otherwise idle.
  SavingsPlanActionState viewFor(SavingsPlanAction kind, [String? planId]) =>
      startedBy(kind, planId) ? this : const SavingsPlanActionState();

  /// Whether another flow's action is still sending.
  bool busyFor(SavingsPlanAction kind, [String? planId]) =>
      phase == SavingsPlanActionPhase.sending && !startedBy(kind, planId);

  @override
  List<Object?> get props => [
    phase,
    action,
    requestedPlanId,
    planId,
    result,
    message,
  ];
}

const _unconfirmed =
    "We couldn't confirm this. Check your plan before trying again.";

final savingsPlanActionProvider =
    NotifierProvider.autoDispose<
      SavingsPlanActionNotifier,
      SavingsPlanActionState
    >(SavingsPlanActionNotifier.new);

/// Runs one plan action at a time. A POST is never retried here.
class SavingsPlanActionNotifier extends Notifier<SavingsPlanActionState> {
  @override
  SavingsPlanActionState build() => const SavingsPlanActionState();

  /// Tops up [planId] from Boc Flex with [amountNaira].
  Future<void> fund(String planId, String amountNaira) => _run(
    SavingsPlanAction.fund,
    planId,
    () =>
        ref.read(coreSavingsPlanServiceProvider).fundPlan(planId, amountNaira),
    _withResult,
  );

  /// Withdraws [planId] early into Boc Flex.
  Future<void> liquidate(String planId) => _run(
    SavingsPlanAction.liquidate,
    planId,
    () => ref.read(coreSavingsPlanServiceProvider).liquidatePlan(planId),
    _withResult,
    forbidden: 'This plan can no longer be withdrawn.',
  );

  /// Creates a plan funded from Boc Flex; [SavingsPlanActionState.planId]
  /// is the new plan's once done.
  Future<void> create(CreateSavingsPlanRequest request) => _run<String>(
    SavingsPlanAction.create,
    null,
    () => ref.read(coreSavingsPlanServiceProvider).createPlan(request),
    (planId) => (planId, null),
  );

  static (String?, SavingsPlanActionResult?) _withResult(
    SavingsPlanActionResult result,
  ) => (result.planId, result);

  Future<void> _run<T>(
    SavingsPlanAction action,
    String? planId,
    Future<NotifierState<T>> Function() call,
    (String?, SavingsPlanActionResult?) Function(T data) done, {
    String? forbidden,
  }) async {
    if (state.phase == SavingsPlanActionPhase.sending) return;
    // The sheet can close mid-request; stay alive so the reply still
    // refreshes the plan and the balance.
    final link = ref.keepAlive();
    try {
      await _send(action, planId, call, done, forbidden);
    } finally {
      link.close();
    }
  }

  Future<void> _send<T>(
    SavingsPlanAction action,
    String? planId,
    Future<NotifierState<T>> Function() call,
    (String?, SavingsPlanActionResult?) Function(T data) done,
    String? forbidden,
  ) async {
    state = SavingsPlanActionState(
      phase: SavingsPlanActionPhase.sending,
      action: action,
      requestedPlanId: planId,
    );
    final reply = await call();
    if (!ref.mounted) return;

    final data = reply.data;
    if (reply.isDone && data != null) {
      final (donePlanId, result) = done(data);
      state = SavingsPlanActionState(
        phase: SavingsPlanActionPhase.done,
        action: action,
        requestedPlanId: planId,
        planId: donePlanId,
        result: result,
      );
      _refresh(state.planId);
      return;
    }

    final code = reply.statusCode;
    // No response, a server error, or a 2xx we could not read: the action
    // may have happened.
    final unknown =
        reply.isError &&
        (code == null || code >= 500 || (code >= 200 && code < 300));
    if (unknown) {
      state = SavingsPlanActionState(
        phase: SavingsPlanActionPhase.unknown,
        action: action,
        requestedPlanId: planId,
        message: _unconfirmed,
      );
      _refresh(planId);
      return;
    }
    state = SavingsPlanActionState(
      phase: SavingsPlanActionPhase.failed,
      action: action,
      requestedPlanId: planId,
      message: code == 403 && forbidden != null
          ? forbidden
          : reply.message ?? 'Request failed.',
    );
  }

  /// Reloads the plan lists, [planId]'s detail when there is one, and the
  /// Boc Flex balance.
  void _refresh(String? planId) {
    ref.invalidate(savingsPlansProvider);
    if (planId != null) ref.invalidate(savingsPlanDetailProvider(planId));
    ref.read(refreshFlexTransactionHistoryProvider)().ignore();
    ref.read(customerBankAccountsProvider.notifier).load().ignore();
  }
}
