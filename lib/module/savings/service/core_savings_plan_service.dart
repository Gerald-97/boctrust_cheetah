import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/interest_accrual_models.dart';
import '../model/savings_plan_models.dart';

const _plansUnavailable = 'Savings plans are not available right now.';

final coreSavingsPlanServiceProvider = Provider<CoreSavingsPlanService>(
  (ref) => CoreSavingsPlanService(ref.watch(coreApiServiceProvider)),
);

/// Reads the customer's Core savings plans. Replies carry account numbers
/// and plan history, so they are logged by path template only.
///
/// A null [_api] means `CORE_BASE_URL` is not configured; every read then
/// reports blocked.
class CoreSavingsPlanService {
  const CoreSavingsPlanService(this._api);
  final ApiService? _api;

  /// The caller's plans of [product], with the product's balance.
  Future<NotifierState<List<SavingsProductGroup>>> getPlans(
    SavingsProductType product,
  ) async {
    final api = _api;
    final code = product.coreCode;
    if (api == null || code == null) {
      return const NotifierState.blocked(_plansUnavailable);
    }
    return NotifierState.fromResponse(
      await api.getData<List<SavingsProductGroup>>(
        CoreApiEndpoints.savingsPlans,
        queryParameters: {'productCode': code},
        parser: SavingsProductGroup.listFromJson,
        requestExtra: const {
          LoggingInterceptor.privacySensitivePathKey:
              CoreApiEndpoints.savingsPlans,
        },
      ),
    );
  }

  /// One of the caller's plans with its history; 404 when it is not theirs.
  Future<NotifierState<SavingsPlanDetail>> getPlan(String planId) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_plansUnavailable);
    return NotifierState.fromResponse(
      await api.getData<SavingsPlanDetail>(
        CoreApiEndpoints.savingsPlan(planId),
        parser: SavingsPlanDetail.fromJson,
        requestExtra: const {
          LoggingInterceptor.privacySensitivePathKey:
              CoreApiEndpoints.savingsPlanTemplate,
        },
      ),
    );
  }

  /// One page of a plan's daily interest, newest first; 404 when the plan is
  /// not the caller's.
  Future<NotifierState<InterestAccrualPage>> getPlanAccruals(
    String planId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_plansUnavailable);
    return NotifierState.fromResponse(
      await api.getData<InterestAccrualPage>(
        CoreApiEndpoints.savingsPlanAccruals(planId),
        queryParameters: {'page': page, 'pageSize': pageSize},
        parser: (json) =>
            InterestAccrualPage.fromJson(json, baseKey: 'principalAmount'),
      ),
    );
  }
}
