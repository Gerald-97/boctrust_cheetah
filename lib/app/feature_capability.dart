import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';
import 'core_api_endpoints.dart';
import 'services.dart';

/// The service an operation belongs to. User and Core paths are never
/// interchangeable, even when they look alike.
enum ApiBackend { user, core }

typedef ApiOperation = ({ApiBackend backend, String method, String path});

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
  // Core mobile banking slices. Each is registered only when its slice
  // (endpoint, models, service, provider, widgets, tests and gates) ships;
  // until then it is unavailable.
  coreAccountOpening,
  ownAccountTransfers,
  savingsWithdrawals,
  boctrustTransfers,
  interbankTransfers,
  billerDirectoryView,
  airtimePurchase,
  dataPurchase,
  billPayment,
  beneficiariesManage,
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
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccounts,
      ),
    },
  ),
  FeatureCapability.savingsCatalogueView: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccounts,
      ),
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankProducts,
      ),
    },
  ),
  FeatureCapability.linkedBanksView: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: ApiEndpoints.withdrawalBankAccounts,
      ),
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: _withdrawalBankAccountById,
      ),
    },
  ),
  FeatureCapability.linkedBanksManage: CapabilityRequirement(
    operations: {
      (backend: ApiBackend.user, method: 'GET', path: ApiEndpoints.banks),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.resolveWithdrawalBankAccount,
      ),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.withdrawalBankAccounts,
      ),
      (
        backend: ApiBackend.user,
        method: 'DELETE',
        path: _withdrawalBankAccountById,
      ),
    },
  ),
  FeatureCapability.kycIdentity: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: ApiEndpoints.ownKycStatus,
      ),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.initiateIdentityVerification,
      ),
    },
  ),
  FeatureCapability.kycGovernmentId: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: ApiEndpoints.ownKycStatus,
      ),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.initiateGovernmentIdVerification,
      ),
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: ApiEndpoints.kycProviderConfig,
      ),
      (
        backend: ApiBackend.user,
        method: 'GET',
        path: ApiEndpoints.governmentIdDocumentTypes,
      ),
    },
  ),
  FeatureCapability.kycUtilityBill: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.initiateUtilityBillUpload,
      ),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: _completeUtilityBillUpload,
      ),
    },
  ),
  FeatureCapability.passwordPinControls: CapabilityRequirement(
    operations: {
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.changePassword,
      ),
      (backend: ApiBackend.user, method: 'POST', path: ApiEndpoints.changePin),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.verifyCurrentPassword,
      ),
      (
        backend: ApiBackend.user,
        method: 'POST',
        path: ApiEndpoints.verifyCurrentPin,
      ),
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

/// Availability of [requirement] given which backends this build can reach.
///
/// A capability is available only when every backend its operations need is
/// configured; a missing Core transport never affects a User capability.
FeatureAvailability availabilityFor(
  CapabilityRequirement? requirement, {
  required Set<ApiBackend> configuredBackends,
}) {
  if (requirement == null) return FeatureAvailability.unavailable;
  if (requirement.comingSoon) return FeatureAvailability.comingSoon;
  if (requirement.localOnly) return FeatureAvailability.available;
  if (requirement.operations.isEmpty) return FeatureAvailability.unavailable;
  final reachable = requirement.operations.every(
    (operation) => configuredBackends.contains(operation.backend),
  );
  return reachable
      ? FeatureAvailability.available
      : FeatureAvailability.unavailable;
}

/// The structural registry check: whether a contract is declared at all,
/// regardless of which backends this build is configured for.
FeatureAvailability availabilityOf(FeatureCapability capability) =>
    availabilityFor(
      capabilityRequirements[capability],
      configuredBackends: ApiBackend.values.toSet(),
    );

/// The backends this build can reach. User is always configured; Core only
/// when `CORE_BASE_URL` is set.
final configuredApiBackendsProvider = Provider<Set<ApiBackend>>(
  (ref) => {ApiBackend.user, if (Env.hasCoreBaseUrl) ApiBackend.core},
);

/// Screens read availability through this provider so tests can override a
/// single capability without touching the registry.
final featureAvailabilityProvider =
    Provider.family<FeatureAvailability, FeatureCapability>(
      (ref, capability) => availabilityFor(
        capabilityRequirements[capability],
        configuredBackends: ref.watch(configuredApiBackendsProvider),
      ),
    );

extension FeatureAvailabilityX on FeatureAvailability {
  bool get isAvailable => this == FeatureAvailability.available;
}
