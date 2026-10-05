import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/beneficiary_models.dart';

const _unavailable = 'Beneficiaries are not available right now.';

final coreBeneficiaryServiceProvider = Provider<CoreBeneficiaryService>(
  (ref) => CoreBeneficiaryService(ref.watch(coreApiServiceProvider)),
);

/// The caller's saved bank accounts and biller customers.
class CoreBeneficiaryService {
  const CoreBeneficiaryService(this._api);
  final ApiService? _api;

  Future<NotifierState<List<Beneficiary>>> list() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    return NotifierState.fromResponse(
      await api.getData<List<Beneficiary>>(
        CoreApiEndpoints.beneficiaries,
        parser: Beneficiary.listFromJson,
      ),
    );
  }

  /// [body] from `bankBeneficiaryRequest` or `billBeneficiaryRequest`.
  Future<NotifierState<Beneficiary>> add(Map<String, Object?> body) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    return NotifierState.fromResponse(
      await api.postData<Beneficiary>(
        CoreApiEndpoints.beneficiaries,
        data: body,
        parser: (json) =>
            Beneficiary.tryParse(json) ??
            (throw const FormatException('Invalid beneficiary.')),
      ),
    );
  }

  Future<NotifierState<bool>> delete(String id) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    return NotifierState.fromResponse(
      await api.deleteData<bool>(
        CoreApiEndpoints.beneficiary(id),
        parser: (_) => true,
      ),
    );
  }
}
