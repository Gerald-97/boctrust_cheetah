import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/bill_models.dart';
import '../model/core_submission_models.dart';

const _billsUnavailable = 'Bill payments are not available right now.';

final coreBillServiceProvider = Provider<CoreBillService>(
  (ref) => CoreBillService(ref.watch(coreApiServiceProvider)),
);

/// Bill catalogues and payments from the caller's BocFlex account.
class CoreBillService {
  const CoreBillService(this._api);
  final ApiService? _api;

  Future<NotifierState<T>> _read<T>(
    String path,
    T Function(Object? json) parser,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_billsUnavailable);
    return NotifierState.fromResponse(
      await api.getData<T>(path, parser: parser),
    );
  }

  Future<NotifierState<List<BillerCategory>>> getCategories() =>
      _read(CoreApiEndpoints.billerCategories, BillerCategory.listFromJson);

  Future<NotifierState<List<Biller>>> getBillers() =>
      _read(CoreApiEndpoints.billers, Biller.listFromJson);

  Future<NotifierState<List<PaymentItem>>> getPaymentItems() =>
      _read(CoreApiEndpoints.paymentItems, PaymentItem.listFromJson);

  /// Sends exactly one POST and never retries.
  Future<ServiceResponse<CoreTransferAck>> pay(
    BillPaymentDraft draft, {
    required String transactionPin,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(transactionPin)) {
      return const ServiceResponse.error('Enter a valid transaction PIN.');
    }
    final api = _api;
    if (api == null) {
      return const ServiceResponse<CoreTransferAck>(
        status: ServiceStatus.blocked,
        message: _billsUnavailable,
      );
    }
    return api.postData<CoreTransferAck>(
      CoreApiEndpoints.billPayments,
      data: {...draft.toJson(), 'transactionPin': transactionPin},
      parser: CoreTransferAck.fromJson,
    );
  }
}
