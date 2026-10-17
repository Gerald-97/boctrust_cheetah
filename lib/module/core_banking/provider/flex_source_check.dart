import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/customer_bank_account_models.dart';
import 'core_account_providers.dart';

/// Shown instead of sending a savings top-up or a new plan.
const kSavingsPausedMessage = 'Saving is paused while Boc Flex is frozen';

/// Whether a customer entry point should be paused: the loaded Boc Flex
/// account is frozen. A customer with no single Core Flex account is not
/// paused; Core decides when the request is sent.
final flexDebitPausedProvider = Provider<bool>((ref) {
  final flex = ref.watch(customerBankAccountsProvider).data?.flexAccount;
  return flex?.status == CoreAccountStatus.frozen;
});

/// What a fresh read of Boc Flex says about debiting it.
enum FlexDebitCheck { allowed, frozen, unconfirmed }

/// Shown when the Boc Flex status could not be read, so nothing was sent.
const kFlexUnconfirmedMessage =
    'We could not confirm your Boc Flex status. Try again.';

/// Reads Boc Flex again from Core. A frozen account is
/// [FlexDebitCheck.frozen]; a status that could not be read, or is closed or
/// unknown, is [FlexDebitCheck.unconfirmed]. Either way nothing is sent. With
/// no single Core Flex account there is nothing to find frozen, so Core's
/// own answer to the request stands.
final freshFlexDebitCheckProvider = Provider<Future<FlexDebitCheck> Function()>(
  (ref) {
    return () async {
      final accounts = ref.read(customerBankAccountsProvider.notifier);
      CustomerBankAccountsData? data() =>
          ref.read(customerBankAccountsProvider).data;
      // A load that just finished (e.g. after a payment) is the fresh read.
      await accounts.settleLoad();
      if (data() == null) await accounts.load();
      if (data() == null) return FlexDebitCheck.unconfirmed;
      final number = data()?.flexAccount?.accountNumber;
      if (number == null) return FlexDebitCheck.allowed;
      var confirmed = await accounts.refreshAccount(number);
      // A load that started meanwhile replaced the list with fresh data.
      if (!confirmed && await accounts.settleLoad()) {
        confirmed = !ref.read(customerBankAccountsProvider).isError;
      }
      final latest = data();
      if (!confirmed || latest == null) return FlexDebitCheck.unconfirmed;
      final flex = latest.flexAccount;
      return switch (flex?.status) {
        null || CoreAccountStatus.active => FlexDebitCheck.allowed,
        CoreAccountStatus.frozen => FlexDebitCheck.frozen,
        CoreAccountStatus.closed ||
        CoreAccountStatus.unknown => FlexDebitCheck.unconfirmed,
      };
    };
  },
);
