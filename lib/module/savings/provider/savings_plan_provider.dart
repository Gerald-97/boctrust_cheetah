import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/savings_plan_models.dart';
import '../service/core_savings_plan_service.dart';

/// The customer's plans of one product. Re-read when the session changes,
/// so plans never outlive the customer they belong to, and dropped when no
/// screen shows them.
final savingsPlansProvider = FutureProvider.autoDispose
    .family<NotifierState<List<SavingsProductGroup>>, SavingsProductType>((
      ref,
      product,
    ) {
      ref.watch(authSessionProvider);
      return ref.read(coreSavingsPlanServiceProvider).getPlans(product);
    });

/// One plan with its history, keyed by its server `planId`.
final savingsPlanDetailProvider = FutureProvider.autoDispose
    .family<NotifierState<SavingsPlanDetail>, String>((ref, planId) {
      ref.watch(authSessionProvider);
      return ref.read(coreSavingsPlanServiceProvider).getPlan(planId);
    });
