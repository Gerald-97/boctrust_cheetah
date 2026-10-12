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
  );

  Future<void> _run(
    String planId,
    Future<NotifierState<SavingsPlanActionResult>> Function() call,
  ) async {
    if (state.phase == SavingsPlanActionPhase.sending) return;
    state = const SavingsPlanActionState(phase: SavingsPlanActionPhase.sending);
    final reply = await call();
    if (!ref.mounted) return;

    final result = reply.data;
    if (reply.isDone && result != null) {
      state = SavingsPlanActionState(
        phase: SavingsPlanActionPhase.done,
        planId: result.planId,
        result: result,
      );
      _refresh(result.planId);
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
      message: reply.message ?? 'Request failed.',
    );
  }

  void _refresh(String planId) {
    ref.invalidate(savingsPlansProvider);
    ref.invalidate(savingsPlanDetailProvider(planId));
    ref.read(customerBankAccountsProvider.notifier).load();
  }
}
