import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';

typedef ApiOperation = ({String method, String path});

enum FeatureAvailability { available, comingSoon, unavailable }

/// Every customer-facing flow the app can show. Read-only displays and the
/// actions on them are separate capabilities: a screen may be viewable while
/// each action on it stays unavailable until its own contract exists.
enum FeatureCapability {
  // Live read-only displays.
  flexSavingsView,
  savingsCatalogueView,
  linkedBanksView,
  // Live actions with an endpoint, typed models, service and provider.
  linkedBanksManage,
  kycIdentity,
  kycGovernmentId,
  kycUtilityBill,
  passwordPinControls,
  // Device-only settings.
  notificationPreferences,
  accessibilityPreferences,
  // Actions without a contract yet, one capability per action.
  flexTopUp,
  flexWithdraw,
  flexStatement,
  flexAutoSave,
  smartSaveCreate,
  fixedDepositCreate,
  padiCreate,
  padiJoin,
  savingsPlansView,
  savingsPlanDeposit,
  savingsPlanEdit,
  savingsPlanWithdraw,
  kycCacDocument,
  kycBankStatement,
  deviceSessions,
  accountDeletion,
  accountStatement,
  freezeAccount,
  biometricLogin,
  biometricTransfers,
  limitIncrease,
  changeMobile,
  walletFunding,
  cardFunding,
  transfers,
  beneficiaries,
  transactionHistory,
  transactionReceipts,
  receiptSharing,
  airtime,
  data,
  bills,
  scanToPay,
  // Products that have not launched.
  loans,
  cards,
}

class CapabilityRequirement {
  const CapabilityRequirement({
    this.operations = const {},
    this.localOnly = false,
    this.comingSoon = false,
  });

  /// Every endpoint the action needs. Listed only once the endpoint, typed
  /// request/response models, service method and provider mapping all exist.
  final Set<ApiOperation> operations;

  /// A device-only feature that needs no API.
  final bool localOnly;

  /// A product that has not launched.
  final bool comingSoon;
}

const _withdrawalBankAccountById =
    '${ApiEndpoints.withdrawalBankAccounts}/{bankAccountId}';
const _completeUtilityBillUpload =
    '/users/me/kyc/utility-bill/{verificationId}/complete';

/// The single source of truth for what the app may do. A capability missing
/// from this map has no contract and is unavailable.
const capabilityRequirements = <FeatureCapability, CapabilityRequirement>{
  FeatureCapability.flexSavingsView: CapabilityRequirement(
    operations: {(method: 'GET', path: ApiEndpoints.ownHome)},
  ),
  FeatureCapability.savingsCatalogueView: CapabilityRequirement(
    operations: {(method: 'GET', path: ApiEndpoints.ownHome)},
  ),
  FeatureCapability.linkedBanksView: CapabilityRequirement(
    operations: {
      (method: 'GET', path: ApiEndpoints.withdrawalBankAccounts),
      (method: 'GET', path: _withdrawalBankAccountById),
    },
  ),
  FeatureCapability.linkedBanksManage: CapabilityRequirement(
    operations: {
      (method: 'GET', path: ApiEndpoints.banks),
      (method: 'POST', path: ApiEndpoints.resolveWithdrawalBankAccount),
      (method: 'POST', path: ApiEndpoints.withdrawalBankAccounts),
      (method: 'DELETE', path: _withdrawalBankAccountById),
    },
  ),
  FeatureCapability.kycIdentity: CapabilityRequirement(
    operations: {
      (method: 'GET', path: ApiEndpoints.ownKycStatus),
      (method: 'POST', path: ApiEndpoints.initiateIdentityVerification),
    },
  ),
  FeatureCapability.kycGovernmentId: CapabilityRequirement(
    operations: {
      (method: 'GET', path: ApiEndpoints.ownKycStatus),
      (method: 'POST', path: ApiEndpoints.initiateGovernmentIdVerification),
    },
  ),
  FeatureCapability.kycUtilityBill: CapabilityRequirement(
    operations: {
      (method: 'POST', path: ApiEndpoints.initiateUtilityBillUpload),
      (method: 'POST', path: _completeUtilityBillUpload),
    },
  ),
  FeatureCapability.passwordPinControls: CapabilityRequirement(
    operations: {
      (method: 'POST', path: ApiEndpoints.changePassword),
      (method: 'POST', path: ApiEndpoints.changePin),
      (method: 'POST', path: ApiEndpoints.verifyCurrentPassword),
      (method: 'POST', path: ApiEndpoints.verifyCurrentPin),
    },
  ),
  FeatureCapability.notificationPreferences: CapabilityRequirement(
    localOnly: true,
  ),
  FeatureCapability.accessibilityPreferences: CapabilityRequirement(
    localOnly: true,
  ),
  FeatureCapability.loans: CapabilityRequirement(comingSoon: true),
  FeatureCapability.cards: CapabilityRequirement(comingSoon: true),
};

FeatureAvailability availabilityOf(FeatureCapability capability) {
  final requirement = capabilityRequirements[capability];
  if (requirement == null) return FeatureAvailability.unavailable;
  if (requirement.comingSoon) return FeatureAvailability.comingSoon;
  if (requirement.localOnly || requirement.operations.isNotEmpty) {
    return FeatureAvailability.available;
  }
  return FeatureAvailability.unavailable;
}

/// Screens read availability through this provider so tests can override a
/// single capability without touching the registry.
final featureAvailabilityProvider =
    Provider.family<FeatureAvailability, FeatureCapability>(
      (ref, capability) => availabilityOf(capability),
    );

extension FeatureAvailabilityX on FeatureAvailability {
  bool get isAvailable => this == FeatureAvailability.available;
}
