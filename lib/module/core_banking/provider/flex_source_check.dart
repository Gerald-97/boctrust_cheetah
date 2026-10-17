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

/// What a fresh read of Boc Flex says about debiting it.
enum FlexDebitCheck { allowed, frozen, unconfirmed }

/// Shown when the Boc Flex status could not be read, so nothing was sent.
const kFlexUnconfirmedMessage =
    'We could not confirm your Boc Flex status. Try again.';

/// Reads Boc Flex again from Core. A missing or inactive account is
/// [FlexDebitCheck.frozen]; a status that could not be read is
/// [FlexDebitCheck.unconfirmed]. Either way nothing is sent.
final freshFlexDebitCheckProvider = Provider<Future<FlexDebitCheck> Function()>(
  (ref) {
    return () async {
      final accounts = ref.read(customerBankAccountsProvider.notifier);
      CustomerBankAccountsData? data() =>
          ref.read(customerBankAccountsProvider).data;
      // A load that just finished (e.g. after a payment) is the fresh read.
      await accounts.settleLoad();
      if (data() == null) await accounts.load();
      final number = data()?.flexAccount?.accountNumber;
      if (data() == null) return FlexDebitCheck.unconfirmed;
      if (number == null) return FlexDebitCheck.frozen;
      var confirmed = await accounts.refreshAccount(number);
      // A load that started meanwhile replaced the list with fresh data.
      if (!confirmed && await accounts.settleLoad()) {
        confirmed = !ref.read(customerBankAccountsProvider).isError;
      }
      if (!confirmed) return FlexDebitCheck.unconfirmed;
      return flexCanBeDebited(data())
          ? FlexDebitCheck.allowed
          : FlexDebitCheck.frozen;
    };
  },
);
