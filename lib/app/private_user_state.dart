import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/account/provider/account_deletion_provider.dart';
import '../module/account/provider/account_preferences_provider.dart';
import '../module/account/provider/user_providers.dart';
import '../module/account/provider/withdrawal_bank_providers.dart';
import '../module/core_banking/provider/core_account_providers.dart';
import '../module/core_banking/provider/core_payments_providers.dart';
import '../module/core_banking/provider/intrabank_submission_providers.dart';
import '../module/home/provider/home_provider.dart';
import '../module/kyc/provider/kyc_configuration_provider.dart';
import '../module/kyc/provider/kyc_providers.dart';
import '../module/kyc/provider/kyc_status_provider.dart';
import '../module/savings/provider/savings_plan_provider.dart';
import '../module/send/provider/transaction_provider.dart';

/// Drops every feature's per-user state, so the next account signed in on this
/// device never sees the previous user's profile, KYC, or balances. Logout,
/// session expiry, and sign-in all go through this one list.
void clearPrivateUserState(Ref ref) {
  ref.read(userProfileProvider.notifier).clear();
  ref.read(userTierProvider.notifier).clear();
  ref.read(userHomeProvider.notifier).clear();
  ref.read(customerBankAccountsProvider.notifier).clear();
  ref.read(coreBankProductsProvider.notifier).clear();
  ref.read(ownAccountMoveProvider.notifier).clear();
  ref.read(interbankBanksProvider.notifier).clear();
  ref.read(billerCategoriesProvider.notifier).clear();
  ref.read(billersProvider.notifier).clear();
  ref.read(paymentItemsProvider.notifier).clear();
  ref.read(beneficiariesProvider.notifier).clear();
  ref.read(boctrustTransferProvider.notifier).clear();
  ref.read(interbankTransferProvider.notifier).clear();
  ref.read(billPaymentProvider.notifier).clear();
  ref.read(profileImageSignedUrlProvider.notifier).clear();
  ref.read(identityVerificationProvider.notifier).clear();
  ref.read(governmentIdVerificationProvider.notifier).clear();
  ref.read(utilityBillUploadProvider.notifier).clear();
  ref.read(kycStatusProvider.notifier).clear();
  ref.read(kycProviderConfigProvider.notifier).clear();
  ref.read(governmentIdDocumentTypesProvider.notifier).clear();
  ref.read(accountDeletionEligibilityProvider.notifier).clear();
  ref.read(accountDeletionProvider.notifier).clear();
  ref.invalidate(accessibilityPreferencesProvider);
  ref.invalidate(notificationPreferencesProvider);
  ref.read(savingsPlansProvider.notifier).clear();
  ref.read(transactionHistoryProvider.notifier).clear();
  ref.read(bankCatalogueProvider.notifier).clear();
  ref.read(withdrawalBankAccountsProvider.notifier).clear();
  ref.read(withdrawalBankDraftProvider.notifier).clear();
}
