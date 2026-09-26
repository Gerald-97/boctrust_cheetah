import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/savings_plan_models.dart';

const _plansUnavailable = 'Savings plans are not available yet.';

/// The customer's SmartSave, Fixed Deposit and Padi plans. No plans contract
/// exists yet, so loading reports unavailability and no plan is ever shown
/// that the server did not return.
final savingsPlansProvider =
    NotifierProvider<SavingsPlansNotifier, NotifierState<List<SavingsPlan>>>(
      SavingsPlansNotifier.new,
    );

class SavingsPlansNotifier extends Notifier<NotifierState<List<SavingsPlan>>> {
  @override
  NotifierState<List<SavingsPlan>> build() => const NotifierState.idle();

  Future<void> load() async =>
      state = const NotifierState.error(_plansUnavailable);

  void clear() => state = const NotifierState.idle();
}
