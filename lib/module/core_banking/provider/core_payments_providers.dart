import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/session_scoped_notifier.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/beneficiary_models.dart';
import '../model/bill_models.dart';
import '../model/core_submission_models.dart';
import '../model/interbank_models.dart';
import '../service/core_beneficiary_service.dart';
import '../service/core_bill_service.dart';
import '../service/core_transfer_service.dart';
import 'core_submission_notifier.dart';

// Reads.

final interbankBanksProvider =
    NotifierProvider<
      InterbankBanksNotifier,
      NotifierState<List<CommercialBank>>
    >(InterbankBanksNotifier.new);

class InterbankBanksNotifier
    extends SessionScopedNotifier<List<CommercialBank>> {
  @override
  String get failureMessage => 'Unable to load banks.';

  @override
  Future<NotifierState<List<CommercialBank>>> fetch() =>
      ref.read(coreTransferServiceProvider).getBanks();
}

final billerCategoriesProvider =
    NotifierProvider<
      BillerCategoriesNotifier,
      NotifierState<List<BillerCategory>>
    >(BillerCategoriesNotifier.new);

class BillerCategoriesNotifier
    extends SessionScopedNotifier<List<BillerCategory>> {
  @override
  String get failureMessage => 'Unable to load bill categories.';

  @override
  Future<NotifierState<List<BillerCategory>>> fetch() =>
      ref.read(coreBillServiceProvider).getCategories();
}

final billersProvider =
    NotifierProvider<BillersNotifier, NotifierState<List<Biller>>>(
      BillersNotifier.new,
    );

class BillersNotifier extends SessionScopedNotifier<List<Biller>> {
  @override
  String get failureMessage => 'Unable to load billers.';

  @override
  Future<NotifierState<List<Biller>>> fetch() =>
      ref.read(coreBillServiceProvider).getBillers();
}

final paymentItemsProvider =
    NotifierProvider<PaymentItemsNotifier, NotifierState<List<PaymentItem>>>(
      PaymentItemsNotifier.new,
    );

class PaymentItemsNotifier extends SessionScopedNotifier<List<PaymentItem>> {
  @override
  String get failureMessage => 'Unable to load plans.';

  @override
  Future<NotifierState<List<PaymentItem>>> fetch() =>
      ref.read(coreBillServiceProvider).getPaymentItems();
}

final beneficiariesProvider =
    NotifierProvider<BeneficiariesNotifier, NotifierState<List<Beneficiary>>>(
      BeneficiariesNotifier.new,
    );

/// Saved beneficiaries. Adds and deletes change the list only after Core
/// confirms them.
class BeneficiariesNotifier extends SessionScopedNotifier<List<Beneficiary>> {
  @override
  String get failureMessage => 'Unable to load your beneficiaries.';

  @override
  Future<NotifierState<List<Beneficiary>>> fetch() =>
      ref.read(coreBeneficiaryServiceProvider).list();

  /// Null on success, otherwise the message to show.
  Future<String?> add(Map<String, Object?> body) async {
    final token = ref.read(authSessionProvider)?.accessToken;
    final result = await ref.read(coreBeneficiaryServiceProvider).add(body);
    final saved = result.data;
    if (saved == null) {
      return result.statusCode == 409
          ? 'This beneficiary is already saved.'
          : result.message ?? 'We could not save this beneficiary.';
    }
    // A list load started before the save would land later without it and
    // overwrite the new row, so let it finish first.
    if (isLoadInFlight) await load();
    if (ref.mounted && ref.read(authSessionProvider)?.accessToken == token) {
      final rows = state.data;
      if (rows == null) {
        unawaited(load());
      } else if (!rows.any((row) => row.id == saved.id)) {
        state = NotifierState.done(List.unmodifiable([...rows, saved]));
      }
    }
    return null;
  }

  /// Null on success, otherwise the message to show.
  Future<String?> delete(String id) async {
    final token = ref.read(authSessionProvider)?.accessToken;
    final result = await ref.read(coreBeneficiaryServiceProvider).delete(id);
    if (result.status != ServiceStatus.success) {
      return result.message ?? 'We could not remove this beneficiary.';
    }
    if (ref.mounted && ref.read(authSessionProvider)?.accessToken == token) {
      final rows = state.data;
      if (rows != null) {
        state = NotifierState.done(
          List.unmodifiable(rows.where((row) => row.id != id)),
        );
      }
    }
    return null;
  }
}

// Bill payments: one POST per draft, never retried automatically. Transfers
// go through `coreTransferAttemptProvider`.

final billPaymentProvider =
    NotifierProvider<
      BillPaymentNotifier,
      CoreSubmissionState<BillPaymentDraft>
    >(BillPaymentNotifier.new);

class BillPaymentNotifier extends CoreSubmissionNotifier<BillPaymentDraft> {
  @override
  Future<ServiceResponse<CoreTransferAck>> send(
    BillPaymentDraft draft, {
    String? transactionPin,
  }) => transactionPin == null
      ? Future.value(
          const ServiceResponse.error('Enter a valid transaction PIN.'),
        )
      : ref
            .read(coreBillServiceProvider)
            .pay(draft, transactionPin: transactionPin);
}
