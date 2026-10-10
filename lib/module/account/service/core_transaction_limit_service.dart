import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/transaction_limit_models.dart';

final coreTransactionLimitServiceProvider =
    Provider<CoreTransactionLimitService>(
      (ref) => CoreTransactionLimitService(ref.watch(coreApiServiceProvider)),
    );

/// Reads the customer's Core transaction limits. A null [_api] means
/// `CORE_BASE_URL` is not configured, so the read reports blocked.
class CoreTransactionLimitService {
  const CoreTransactionLimitService(this._api);
  final ApiService? _api;

  /// The caller's limits; 403 for a Tier 0 customer.
  Future<NotifierState<TransactionLimits>> getLimits() async {
    final api = _api;
    if (api == null) {
      return const NotifierState.blocked(
        'Transaction limits are not available right now.',
      );
    }
    return NotifierState.fromResponse(
      await api.getData<TransactionLimits>(
        CoreApiEndpoints.transactionLimits,
        parser: TransactionLimits.fromJson,
      ),
    );
  }
}
