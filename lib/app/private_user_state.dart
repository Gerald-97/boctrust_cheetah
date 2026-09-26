import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/account/provider/account_deletion_provider.dart';
import '../module/account/provider/account_preferences_provider.dart';
import '../module/account/provider/user_providers.dart';
import '../module/account/provider/withdrawal_bank_providers.dart';
import '../module/home/provider/home_provider.dart';
import '../module/kyc/provider/document_verification_provider.dart';
import '../module/kyc/provider/kyc_providers.dart';
import '../module/kyc/provider/kyc_status_provider.dart';

/// Drops every feature's per-user state, so the next account signed in on this
/// device never sees the previous user's profile, KYC, or balances. Logout,
/// session expiry, and sign-in all go through this one list.
void clearPrivateUserState(Ref ref) {
  ref.read(userProfileProvider.notifier).clear();
  ref.read(userTierProvider.notifier).clear();
  ref.read(userHomeProvider.notifier).clear();
  ref.read(profileImageSignedUrlProvider.notifier).clear();
  ref.read(identityVerificationProvider.notifier).clear();
  ref.read(governmentIdVerificationProvider.notifier).clear();
  ref.read(utilityBillUploadProvider.notifier).clear();
  ref.read(kycStatusProvider.notifier).clear();
  ref.invalidate(documentVerificationProvider);
  ref.read(accountDeletionEligibilityProvider.notifier).clear();
  ref.read(accountDeletionProvider.notifier).clear();
  ref.invalidate(accessibilityPreferencesProvider);
  ref.invalidate(notificationPreferencesProvider);
  ref.read(bankCatalogueProvider.notifier).clear();
  ref.read(withdrawalBankAccountsProvider.notifier).clear();
  ref.read(withdrawalBankDraftProvider.notifier).clear();
}
