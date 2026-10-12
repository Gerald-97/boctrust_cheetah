import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../core_banking/provider/core_account_providers.dart';
import '../model/savings_plan_models.dart';
import '../service/core_savings_plan_service.dart';
import 'savings_plan_provider.dart';

/// Where a plan action stands. [unknown] means Core may or may not have
/// applied it (no response, a 5xx, or a reply that could not be read).
enum SavingsPlanActionPhase { idle, sending, done, failed, unknown }

class SavingsPlanActionState extends Equatable {
  const SavingsPlanActionState({
    this.phase = SavingsPlanActionPhase.idle,
    this.planId,
    this.result,
    this.message,
  });

  final SavingsPlanActionPhase phase;

  /// The plan the action touched, set once Core confirms it.
  final String? planId;
  final SavingsPlanActionResult? result;
  final String? message;

  @override
  List<Object?> get props => [phase, planId, result, message];
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
    planId,
    () =>
        ref.read(coreSavingsPlanServiceProvider).fundPlan(planId, amountNaira),
    _withResult,
  );

  /// Withdraws [planId] early into Boc Flex.
  Future<void> liquidate(String planId) => _run(
    planId,
    () => ref.read(coreSavingsPlanServiceProvider).liquidatePlan(planId),
    _withResult,
    forbidden: 'This plan can no longer be withdrawn.',
  );

  /// Creates a plan funded from Boc Flex; [SavingsPlanActionState.planId]
  /// is the new plan's once done.
  Future<void> create(CreateSavingsPlanRequest request) => _run<String>(
    null,
    () => ref.read(coreSavingsPlanServiceProvider).createPlan(request),
    (planId) => SavingsPlanActionState(
      phase: SavingsPlanActionPhase.done,
      planId: planId,
    ),
  );

  static SavingsPlanActionState _withResult(SavingsPlanActionResult result) =>
      SavingsPlanActionState(
        phase: SavingsPlanActionPhase.done,
        planId: result.planId,
        result: result,
      );

  Future<void> _run<T>(
    String? planId,
    Future<NotifierState<T>> Function() call,
    SavingsPlanActionState Function(T data) done, {
    String? forbidden,
  }) async {
    if (state.phase == SavingsPlanActionPhase.sending) return;
    // The sheet can close mid-request; stay alive so the reply still
    // refreshes the plan and the balance.
    final link = ref.keepAlive();
    try {
      await _send(planId, call, done, forbidden);
    } finally {
      link.close();
    }
  }

  Future<void> _send<T>(
    String? planId,
    Future<NotifierState<T>> Function() call,
    SavingsPlanActionState Function(T data) done,
    String? forbidden,
  ) async {
    state = const SavingsPlanActionState(phase: SavingsPlanActionPhase.sending);
    final reply = await call();
    if (!ref.mounted) return;

    final data = reply.data;
    if (reply.isDone && data != null) {
      state = done(data);
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
      state = const SavingsPlanActionState(
        phase: SavingsPlanActionPhase.unknown,
        message: _unconfirmed,
      );
      _refresh(planId);
      return;
    }
    state = SavingsPlanActionState(
      phase: SavingsPlanActionPhase.failed,
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
    ref.read(customerBankAccountsProvider.notifier).load();
  }
}
