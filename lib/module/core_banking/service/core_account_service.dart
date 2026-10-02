import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/bank_product_models.dart';
import '../model/customer_bank_account_models.dart';

const _coreUnavailable = 'Account services are not available right now.';

final coreAccountServiceProvider = Provider<CoreAccountService>(
  (ref) => CoreAccountService(ref.watch(coreApiServiceProvider)),
);

/// Reads the customer's Core accounts and the Core product catalogue.
///
/// A null [_api] means `CORE_BASE_URL` is not configured; every read then
/// reports blocked rather than throwing or inventing empty data.
class CoreAccountService {
  const CoreAccountService(this._api);
  final ApiService? _api;

  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    return NotifierState.fromResponse(
      await api.getData<CustomerBankAccountsData>(
        CoreApiEndpoints.bankAccounts,
        parser: CustomerBankAccountsData.fromJson,
      ),
    );
  }

  Future<NotifierState<List<CoreBankProduct>>> getBankProducts() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    return NotifierState.fromResponse(
      await api.getData<List<CoreBankProduct>>(
        CoreApiEndpoints.bankProducts,
        parser: CoreBankProduct.listFromJson,
      ),
    );
  }
}
