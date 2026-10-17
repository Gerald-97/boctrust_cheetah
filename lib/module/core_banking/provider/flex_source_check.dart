import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/customer_bank_account_models.dart';
import 'core_account_providers.dart';

/// Shown instead of sending a savings top-up or a new plan.
const kSavingsPausedMessage = 'Saving is paused while Boc Flex is frozen';

/// Whether the Boc Flex account can be debited, from the loaded accounts:
/// only when it exists and is active.
bool flexCanBeDebited(CustomerBankAccountsData? data) =>
    data?.flexAccount?.isActive == true;

/// Whether a customer entry point should be paused: the accounts have loaded
/// and Boc Flex cannot be debited. An unloaded list pauses nothing here; the
/// fresh check decides before anything is sent.
final flexDebitPausedProvider = Provider<bool>((ref) {
  final data = ref.watch(customerBankAccountsProvider).data;
  return data != null && !flexCanBeDebited(data);
});

/// Reads Boc Flex again from Core and reports whether it can be debited. A
/// missing, inactive, or unconfirmed account is blocked: nothing is sent on
/// a status that could not be checked.
final freshFlexDebitCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final accounts = ref.read(customerBankAccountsProvider.notifier);
    if (ref.read(customerBankAccountsProvider).data == null) {
      await accounts.load();
    }
    final number = ref
        .read(customerBankAccountsProvider)
        .data
        ?.flexAccount
        ?.accountNumber;
    if (number == null || !await accounts.refreshAccount(number)) return false;
    return ref
            .read(customerBankAccountsProvider)
            .data
            ?.flexAccount
            ?.isActive ==
        true;
  };
});
