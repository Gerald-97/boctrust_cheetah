import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_submission_models.dart';
import '../model/intrabank_models.dart';

final coreTransferServiceProvider = Provider<CoreTransferService>(
  (ref) => CoreTransferService(ref.watch(coreApiServiceProvider)),
);

/// Money-moving Core requests. Each method sends exactly one POST and never
/// retries; the caller classifies the result with `mapCoreSubmission`.
class CoreTransferService {
  const CoreTransferService(this._api);
  final ApiService? _api;

  /// Blocked replies are never sent, so they classify as a rejection.
  static const _unconfigured = ServiceResponse<CoreTransferAck>(
    status: ServiceStatus.blocked,
    message: 'Transfers are not available right now.',
  );

  Future<ServiceResponse<CoreTransferAck>> moveBetweenOwnAccounts(
    OwnAccountMoveDraft draft,
  ) async {
    final api = _api;
    if (api == null) return _unconfigured;
    return api.postData<CoreTransferAck>(
      draft.direction == OwnAccountDirection.toSavings
          ? CoreApiEndpoints.ownAccountTransfer
          : CoreApiEndpoints.intrabankWithdrawals,
      data: draft.toJson(),
      parser: CoreTransferAck.fromJson,
    );
  }
}
