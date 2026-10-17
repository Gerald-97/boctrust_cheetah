import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/core_api_endpoints.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a contract is declared at all, whatever this build configures.
FeatureAvailability availabilityOf(FeatureCapability capability) =>
    availabilityFor(
      capabilityRequirements[capability],
      configuredBackends: ApiBackend.values.toSet(),
    );

void main() {
  test('only capabilities with a declared live contract are available', () {
    final available = {
      for (final capability in FeatureCapability.values)
        if (availabilityOf(capability) == FeatureAvailability.available)
          capability,
    };

    // Adding to this set means a new endpoint, typed models, service and
    // provider all landed together; flipping anything else on is a bug.
    expect(available, {
      FeatureCapability.flexSavingsView,
      FeatureCapability.savingsCatalogueView,
      FeatureCapability.linkedBanksView,
      FeatureCapability.linkedBanksManage,
      FeatureCapability.kycIdentity,
      FeatureCapability.kycGovernmentId,
      FeatureCapability.kycUtilityBill,
      FeatureCapability.passwordPinControls,
      FeatureCapability.notificationPreferences,
      FeatureCapability.accessibilityPreferences,
      FeatureCapability.biometricLogin,
      FeatureCapability.biometricTransfers,
    });
  });

  test('the government-ID capability requires both configuration reads', () {
    final operations =
        capabilityRequirements[FeatureCapability.kycGovernmentId]!.operations;
    expect(
      operations,
      containsAll(<ApiOperation>{
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
      }),
    );
  });

  test('money-moving Core operations are staging-only until G2', () {
    // Transfers and bill payment stay out of release builds until
    // transaction-bound authorization and response semantics are published.
    bool movesMoney(ApiOperation operation) =>
        operation.backend == ApiBackend.core &&
        operation.method == 'POST' &&
        CoreApiEndpoints.moneyMoving.contains(operation.path);

    for (final MapEntry(:key, :value) in capabilityRequirements.entries) {
      if (value.operations.any(movesMoney)) {
        expect(value.stagingOnly, isTrue, reason: '$key moves money');
      }
    }
    for (final capability in [
      FeatureCapability.transfers,
      FeatureCapability.airtime,
      FeatureCapability.data,
      FeatureCapability.bills,
    ]) {
      expect(availabilityOf(capability), FeatureAvailability.unavailable);
    }
  });

  test('Core mobile banking slices are available only in staging', () {
    const slices = [
      FeatureCapability.airtime,
      FeatureCapability.data,
      FeatureCapability.bills,
      FeatureCapability.beneficiaries,
      FeatureCapability.coreAccountHistory,
      FeatureCapability.transactionHistory,
      FeatureCapability.savingsPlansView,
      FeatureCapability.savingsPlanDeposit,
      FeatureCapability.savingsPlanWithdraw,
      FeatureCapability.smartSaveCreate,
      FeatureCapability.fixedDepositCreate,
      FeatureCapability.flexInterestView,
      FeatureCapability.transactionLimitsView,
    ];
    for (final capability in slices) {
      expect(availabilityOf(capability), FeatureAvailability.unavailable);
      expect(
        availabilityFor(
          capabilityRequirements[capability],
          configuredBackends: ApiBackend.values.toSet(),
          staging: true,
        ),
        FeatureAvailability.available,
        reason: '$capability',
      );
      expect(
        availabilityFor(
          capabilityRequirements[capability],
          configuredBackends: {ApiBackend.user},
          staging: true,
        ),
        FeatureAvailability.unavailable,
        reason: '$capability needs Core',
      );
    }
  });
  test('scan to pay needs Core name enquiry in staging, not remote OCR', () {
    final requirement = capabilityRequirements[FeatureCapability.scanToPay]!;
    expect(requirement.operations, {
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankNameEnquiry,
      ),
    });
    expect(
      availabilityFor(
        requirement,
        configuredBackends: {ApiBackend.user},
        staging: true,
      ),
      FeatureAvailability.unavailable,
    );
    expect(
      availabilityFor(
        requirement,
        configuredBackends: ApiBackend.values.toSet(),
      ),
      FeatureAvailability.unavailable,
    );
  });

  group('transfer authorization readiness', () {
    test('is on in staging builds only', () {
      bool ready({required bool staging}) {
        final container = ProviderContainer(
          overrides: [stagingModeProvider.overrideWithValue(staging)],
        );
        addTearDown(container.dispose);
        return container.read(transferAuthorizationReadyProvider);
      }

      expect(ready(staging: true), isTrue);
      expect(ready(staging: false), isFalse);
    });

    test('production stays unavailable even when evidence is ready', () {
      expect(
        transferAuthorizationReady(evidenceReady: true, staging: false),
        isFalse,
      );
      expect(
        transferAuthorizationReady(evidenceReady: true, staging: true),
        isTrue,
      );
      expect(
        transferAuthorizationReady(evidenceReady: false, staging: true),
        isFalse,
      );
    });
  });
  // Staged initiate → OTP → finalize; only finalize moves money.
  // Staged initiate → OTP → finalize; only finalize moves money. BOCTRUST
  // reuses the customer name enquiry and pays through the intrabank routes.
  test('staged transfers are staging-only, on customer routes', () {
    const boctrust = FeatureCapability.boctrustTransfers;
    const interbank = FeatureCapability.interbankTransfers;
    Set<String> paths(FeatureCapability c) => {
      for (final o in capabilityRequirements[c]!.operations) o.path,
    };

    for (final capability in [boctrust, interbank]) {
      expect(availabilityOf(capability), FeatureAvailability.unavailable);
      expect(
        availabilityFor(
          capabilityRequirements[capability],
          configuredBackends: ApiBackend.values.toSet(),
          staging: true,
        ),
        FeatureAvailability.available,
      );
      expect(paths(capability).every((p) => p.startsWith('/me/')), isTrue);
    }
    expect(
      paths(boctrust),
      containsAll([
        CoreApiEndpoints.interbankNameEnquiry,
        CoreApiEndpoints.intrabankTransferInitiate,
        CoreApiEndpoints.intrabankTransferPinVerifyTemplate,
        CoreApiEndpoints.intrabankTransferOtpResendTemplate,
        CoreApiEndpoints.intrabankTransferOtpVerifyTemplate,
        CoreApiEndpoints.intrabankTransferFinalizeTemplate,
      ]),
    );
    // The PIN-verify → OTP-verify → bodyless-finalize contract replaced the
    // OTP request; liveness is out of scope.
    for (final capability in [boctrust, interbank]) {
      expect(
        paths(
          capability,
        ).where((p) => p.contains('/otp/request') || p.contains('/liveness/')),
        isEmpty,
      );
    }
    expect(
      paths(boctrust),
      isNot(contains(CoreApiEndpoints.interbankTransferInitiate)),
    );
    expect(
      paths(interbank),
      containsAll([
        CoreApiEndpoints.interbankTransferInitiate,
        CoreApiEndpoints.interbankTransferPinVerifyTemplate,
        CoreApiEndpoints.interbankTransferOtpResendTemplate,
        CoreApiEndpoints.interbankTransferOtpVerifyTemplate,
        CoreApiEndpoints.interbankTransferFinalizeTemplate,
      ]),
    );
    expect(CoreApiEndpoints.moneyMoving, {
      CoreApiEndpoints.billPayments,
      CoreApiEndpoints.intrabankTransferFinalizeTemplate,
      CoreApiEndpoints.interbankTransferFinalizeTemplate,
      CoreApiEndpoints.savingsPlanFundTemplate,
      CoreApiEndpoints.savingsPlanLiquidateTemplate,
      CoreApiEndpoints.savingsPlans,
    });
  });

  // Viewing limits needs only the GET; editing is its own staged capability
  // and moves no money.
  test('limit editing is separate from viewing', () {
    const view = FeatureCapability.transactionLimitsView;
    const edit = FeatureCapability.transactionLimitsEdit;

    expect(capabilityRequirements[view]!.operations, {
      (
        backend: ApiBackend.core,
        method: 'GET',
        path: CoreApiEndpoints.transactionLimits,
      ),
    });
    expect(capabilityRequirements[edit]!.stagingOnly, isTrue);
    expect(
      {for (final o in capabilityRequirements[edit]!.operations) o.path},
      {
        CoreApiEndpoints.transactionLimits,
        CoreApiEndpoints.transactionLimitsInitiate,
        CoreApiEndpoints.transactionLimitPinVerifyTemplate,
        CoreApiEndpoints.transactionLimitOtpResendTemplate,
        CoreApiEndpoints.transactionLimitOtpVerifyTemplate,
        CoreApiEndpoints.transactionLimitFinalizeTemplate,
      },
    );
    expect(
      CoreApiEndpoints.moneyMoving,
      isNot(contains(CoreApiEndpoints.transactionLimitFinalizeTemplate)),
    );
  });

  test('staged check paths encode the reference', () {
    expect(
      CoreApiEndpoints.intrabankTransferPinVerify('a/b'),
      '/me/intrabank/transfers/a%2Fb/pin/verify',
    );
    expect(
      CoreApiEndpoints.interbankTransferOtpVerify('a/b'),
      '/me/interbank/transfers/a%2Fb/otp/verify',
    );
    expect(
      CoreApiEndpoints.interbankTransferOtpResend('a/b'),
      '/me/interbank/transfers/a%2Fb/otp/resend',
    );
    expect(
      CoreApiEndpoints.transactionLimitFinalize('a/b'),
      '/me/transaction-limits/a%2Fb/finalize',
    );
  });
}
