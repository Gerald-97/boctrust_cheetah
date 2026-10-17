import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/session_scoped_notifier.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/bank_product_models.dart';
import '../model/customer_bank_account_models.dart';
import '../service/core_account_service.dart';

final customerBankAccountsProvider =
    NotifierProvider<
      CustomerBankAccountsNotifier,
      NotifierState<CustomerBankAccountsData>
    >(CustomerBankAccountsNotifier.new);

final coreBankProductsProvider =
    NotifierProvider<
      CoreBankProductsNotifier,
      NotifierState<List<CoreBankProduct>>
    >(CoreBankProductsNotifier.new);

class CustomerBankAccountsNotifier
    extends SessionScopedNotifier<CustomerBankAccountsData> {
  @override
  String get failureMessage => 'Unable to load your account balances.';

  @override
  Future<NotifierState<CustomerBankAccountsData>> fetch() =>
      ref.read(coreAccountServiceProvider).getBankAccounts();

  /// Refreshes one account's live balance in place, so every screen reading
  /// the list sees it. A failed or stale refresh leaves the list unchanged.
  /// Returns whether the fresh account was applied.
  Future<bool> refreshAccount(String accountNumber) async {
    final accessToken = ref.read(authSessionProvider)?.accessToken;
    final before = state.data;
    // A full load already refreshes every balance; never compete with it.
    if (before == null || accessToken == null || isLoadInFlight) return false;
    final result = await ref
        .read(coreAccountServiceProvider)
        .getBankAccount(accountNumber);
    final account = result.data;
    // Dropped when the list changed meanwhile (a reload, clear or session
    // change), so a late single result never overwrites newer data.
    if (!ref.mounted ||
        account == null ||
        !identical(state.data, before) ||
        ref.read(authSessionProvider)?.accessToken != accessToken) {
      return false;
    }
    state = NotifierState.done(before.withAccount(account));
    return true;
  }
}

class CoreBankProductsNotifier
    extends SessionScopedNotifier<List<CoreBankProduct>> {
  @override
  String get failureMessage => 'Unable to load savings products.';

  @override
  Future<NotifierState<List<CoreBankProduct>>> fetch() =>
      ref.read(coreAccountServiceProvider).getBankProducts();
}
