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
  // Core mobile banking slices, unavailable until each is registered.
  ownAccountTransfers,
  savingsWithdrawals,
  boctrustTransfers,
  interbankTransfers,
  coreAccountActivity,
  coreAccountHistory,
  // Products that have not launched.
  loans,
  cards,
}

class CapabilityRequirement {
  const CapabilityRequirement({
    this.operations = const {},
    this.localOnly = false,
    this.comingSoon = false,
    this.stagingOnly = false,
  });

  /// Every endpoint the action needs. Listed only once the endpoint, typed
  /// request/response models, service method and provider mapping all exist.
  final Set<ApiOperation> operations;

  /// A device-only feature that needs no API.
  final bool localOnly;

  /// A product that has not launched.
  final bool comingSoon;

  /// Reachable only in staging builds: the endpoints exist but their
  /// response schemas, success semantics or authorization are not yet
  /// published, so staging verifies them against live responses first.
  final bool stagingOnly;
}

const _withdrawalBankAccountById =
    '${ApiEndpoints.withdrawalBankAccounts}/{bankAccountId}';
const _completeUtilityBillUpload =
    '/users/me/kyc/utility-bill/{verificationId}/complete';

const _billPayment = CapabilityRequirement(
  stagingOnly: true,
  operations: {
    (
      backend: ApiBackend.core,
      method: 'GET',
      path: CoreApiEndpoints.billerCategories,
    ),
    (backend: ApiBackend.core, method: 'GET', path: CoreApiEndpoints.billers),
    (
      backend: ApiBackend.core,
      method: 'GET',
      path: CoreApiEndpoints.paymentItems,
    ),
    (
      backend: ApiBackend.core,
      method: 'POST',
      path: CoreApiEndpoints.billPayments,
    ),
  },
);

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
  // The runtime provider still decides whether this device has a usable
  // enrolled biometric.
  FeatureCapability.biometricLogin: CapabilityRequirement(localOnly: true),
  // Core mobile banking, verified on staging before release. Transfers send
  // only after `transferAuthorizationReadyProvider` and a transaction PIN;
  // bill payments still pass `transactionAuthorizerProvider` first.
  FeatureCapability.ownAccountTransfers: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccounts,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.ownAccountTransfer,
      ),
      // A read despite POST: live status of a transfer already sent.
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.intrabankTransferRequeryTemplate,
      ),
    },
  ),
  FeatureCapability.savingsWithdrawals: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccounts,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.intrabankWithdrawals,
      ),
      // A read despite POST: live status of a transfer already sent.
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.intrabankTransferRequeryTemplate,
      ),
    },
  ),
  FeatureCapability.boctrustTransfers: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccounts,
      ),
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.accountEnquiryTemplate,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.intrabankTransfers,
      ),
      // A read despite POST: live status of a transfer already sent.
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.intrabankTransferRequeryTemplate,
      ),
    },
  ),
  FeatureCapability.interbankTransfers: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.interbankBanks,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankNameEnquiry,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankTransfers,
      ),
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.interbankTransferStatusTemplate,
      ),
      // A read despite POST: live status of a transfer already sent.
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankTransferRequeryTemplate,
      ),
    },
  ),
  // Live summary of one account.
  FeatureCapability.coreAccountActivity: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccountSummaryTemplate,
      ),
    },
  ),
  // Live history of one account. Rows stay unshown until their item schema
  // is confirmed; only whether the period has activity is displayed.
  FeatureCapability.coreAccountHistory: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.bankAccountTransactionsTemplate,
      ),
    },
  ),
  // The photo is read on the device; Core only verifies the recipient name.
  FeatureCapability.scanToPay: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankNameEnquiry,
      ),
    },
  ),
  FeatureCapability.airtime: _billPayment,
  FeatureCapability.data: _billPayment,
  FeatureCapability.bills: _billPayment,
  FeatureCapability.beneficiaries: CapabilityRequirement(
    stagingOnly: true,
    operations: {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.beneficiaries,
      ),
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.beneficiaries,
      ),
      (
        backend: ApiBackend.core,
        method: 'DELETE',
        path: CoreApiEndpoints.beneficiaryTemplate,
      ),
    },
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
  bool staging = false,
}) {
  if (requirement == null) return FeatureAvailability.unavailable;
  if (requirement.comingSoon) return FeatureAvailability.comingSoon;
  if (requirement.stagingOnly && !staging) {
    return FeatureAvailability.unavailable;
  }
  if (requirement.localOnly) return FeatureAvailability.available;
  if (requirement.operations.isEmpty) return FeatureAvailability.unavailable;
  final reachable = requirement.operations.every(
    (operation) => configuredBackends.contains(operation.backend),
  );
  return reachable
      ? FeatureAvailability.available
      : FeatureAvailability.unavailable;
}

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
        staging: ref.watch(stagingModeProvider),
      ),
    );

extension FeatureAvailabilityX on FeatureAvailability {
  bool get isAvailable => this == FeatureAvailability.available;
}

/// Whether transfers may be sent with a transaction PIN. On since
/// 7 October 2026 (Kenechukwu): the Core docs, the source of truth, require
/// `transactionPin` on all four transfer bodies and define 401 as an
/// incorrect PIN. [transferAuthorizationReady] still keeps it to staging.
const kTransferAuthorizationEvidenceReady = true;

/// Transfer PIN authorization is never ready outside staging; production
/// activation is a separate release decision.
bool transferAuthorizationReady({
  required bool evidenceReady,
  required bool staging,
}) => evidenceReady && staging;

/// Every transfer PIN submit path checks this first. While false, no
/// PIN-authorized transfer is sent.
final transferAuthorizationReadyProvider = Provider<bool>(
  (ref) => transferAuthorizationReady(
    evidenceReady: kTransferAuthorizationEvidenceReady,
    staging: ref.watch(stagingModeProvider),
  ),
);
